import tkinter as tk
from tkinter import ttk
from tkinter.scrolledtext import ScrolledText
import asyncio
import threading
import queue
import yfinance as yf
import numpy as np
import pandas as pd
import datetime
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split

# -- CONFIGURATION --
SMA_SHORT_PERIOD = 50
SMA_LONG_PERIOD = 200
STOP_LOSS_PERCENTAGE = 0.02
TAKE_PROFIT_PERCENTAGE = 0.05

# -- Technical Indicators --
def calculate_rsi(prices, period=14):
    delta = prices.diff()
    gain = delta.where(delta > 0, 0.0)
    loss = -delta.where(delta < 0, 0.0)
    avg_gain = gain.rolling(window=period).mean()
    avg_loss = loss.rolling(window=period).mean()
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    return rsi

def calculate_macd(prices, fast=12, slow=26, signal=9):
    ema_fast = prices.ewm(span=fast, adjust=False).mean()
    ema_slow = prices.ewm(span=slow, adjust=False).mean()
    macd = ema_fast - ema_slow
    signal_line = macd.ewm(span=signal, adjust=False).mean()
    return macd, signal_line

# -- Data & Model Logic --
def fetch_stock_data(symbol):
    return yf.download(symbol, period="1y", interval="1d", progress=False)

def train_ml_model(symbol):
    data = fetch_stock_data(symbol)
    if data.empty or len(data) < SMA_LONG_PERIOD:
        return None

    data['RSI'] = calculate_rsi(data['Close'])
    data['MACD'], data['Signal'] = calculate_macd(data['Close'])
    data['Price Change'] = data['Close'].pct_change().shift(-1)
    data.dropna(inplace=True)

    features = data[['RSI', 'MACD', 'Signal']]
    target = np.where(data['Price Change'] > 0, 1, 0)

    X_train, X_test, y_train, y_test = train_test_split(features, target, test_size=0.2)
    model = RandomForestClassifier()
    model.fit(X_train, y_train)
    return model

def get_technical_indicators(data):
    sma_short = data['Close'].rolling(window=SMA_SHORT_PERIOD).mean()
    sma_long = data['Close'].rolling(window=SMA_LONG_PERIOD).mean()
    return sma_short, sma_long

def place_stop_loss_and_take_profit(symbol, price):
    stop_loss = price * (1 - STOP_LOSS_PERCENTAGE)
    take_profit = price * (1 + TAKE_PROFIT_PERCENTAGE)
    return f"{symbol}: SL at {stop_loss:.2f}, TP at {take_profit:.2f}"

# -- Hardcoded Stock Symbols --
stock_symbols = [
    "AAPL", "AMZN", "GOOGL", "MSFT", "TSLA", "META", "NVDA", "BRK-B", 
    "UNH", "JNJ", "V", "WMT", "PG", "MA", "DIS", "PYPL", "HD", "NVDA", "BA", "VZ"
]

# -- Async Monitoring Logic --
async def monitor_stocks(queue_out):
    models = {}

    # Load models for the stocks
    for symbol in stock_symbols:
        model = train_ml_model(symbol)
        if model:
            models[symbol] = model

    # Immediate price update after loading models
    prices = {}
    for symbol in models:
        try:
            data = fetch_stock_data(symbol)
            price = data['Close'].iloc[-1]
            prices[symbol] = price
        except:
            continue
    queue_out.put(("__PRICE_UPDATE__", prices, datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")))

    last_price_update = datetime.datetime.min

    while True:
        now = datetime.datetime.now()

        for symbol in models:
            data = fetch_stock_data(symbol)
            if data.empty or len(data) < SMA_LONG_PERIOD:
                continue

            data['RSI'] = calculate_rsi(data['Close'])
            data['MACD'], data['Signal'] = calculate_macd(data['Close'])
            sma_short, sma_long = get_technical_indicators(data)
            price = data['Close'].iloc[-1]
            msg = []

            if sma_short.iloc[-1] > sma_long.iloc[-1]:
                msg.append(f"{symbol}: Bullish crossover.")
            elif sma_short.iloc[-1] < sma_long.iloc[-1]:
                msg.append(f"{symbol}: Bearish crossover.")

            features = np.array([
                data['RSI'].iloc[-1],
                data['MACD'].iloc[-1],
                data['Signal'].iloc[-1]
            ]).reshape(1, -1)

            prediction = models[symbol].predict(features)
            msg.append(f"{symbol}: {'Buy' if prediction == 1 else 'Sell'} Signal")
            msg.append(place_stop_loss_and_take_profit(symbol, price))

            for m in msg:
                queue_out.put(m)

        # Update prices every hour
        if (now - last_price_update).total_seconds() >= 3600 or last_price_update == datetime.datetime.min:
            prices = {}
            for symbol in models:
                try:
                    data = fetch_stock_data(symbol)
                    price = data['Close'].iloc[-1]
                    prices[symbol] = price
                except:
                    continue
            queue_out.put(("__PRICE_UPDATE__", prices, now.strftime("%Y-%m-%d %H:%M:%S")))
            last_price_update = now

        await asyncio.sleep(60)

async def main(queue_out):
    await monitor_stocks(queue_out)

# -- GUI Class --
class StockApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Fortune 500 Stock Monitor")
        self.geometry("1000x700")

        self.queue = queue.Queue()
        self.loop = asyncio.new_event_loop()
        self.task = None
        self.loop_thread = threading.Thread(target=self.loop.run_forever, daemon=True)
        self.loop_thread.start()

        self.last_prices = {}
        self.current_prices = {}
        self.sort_by = ("symbol", False)
        self.last_update_time = ""

        self.setup_ui()
        self.after(100, self.process_queue)

    def setup_ui(self):
        ttk.Label(self, text="Monitoring Fortune 500 Stocks").pack(pady=10)

        button_frame = ttk.Frame(self)
        button_frame.pack(pady=5)

        ttk.Button(button_frame, text="Start Monitoring", command=self.start_monitoring).pack(side=tk.LEFT, padx=5)
        ttk.Button(button_frame, text="Stop Monitoring", command=self.stop_monitoring).pack(side=tk.LEFT, padx=5)

        top_frame = ttk.Frame(self)
        top_frame.pack(fill=tk.BOTH, expand=True)

        self.price_tree = ttk.Treeview(top_frame, columns=("Symbol", "Price"), show="headings", height=25)
        self.price_tree.heading("Symbol", text="Symbol", command=lambda: self.sort_table("symbol"))
        self.price_tree.heading("Price", text="Current Price", command=lambda: self.sort_table("price"))
        self.price_tree.column("Symbol", width=100, anchor="center")
        self.price_tree.column("Price", width=120, anchor="center")
        self.price_tree.pack(side=tk.LEFT, padx=10, pady=10, fill=tk.BOTH, expand=True)

        scrollbar = ttk.Scrollbar(top_frame, orient=tk.VERTICAL, command=self.price_tree.yview)
        self.price_tree.configure(yscroll=scrollbar.set)
        scrollbar.pack(side=tk.LEFT, fill=tk.Y)

        self.update_label = ttk.Label(self, text="Last Update: N/A")
        self.update_label.pack()

        self.text_area = ScrolledText(self, height=15)
        self.text_area.pack(padx=10, pady=10, fill=tk.BOTH, expand=True)

    def sort_table(self, column_name):
        if self.sort_by[0] == column_name:
            self.sort_by = (column_name, not self.sort_by[1])
        else:
            self.sort_by = (column_name, False)
        self.update_price_table(self.current_prices)

    def update_price_table(self, price_dict):
        def _update():
            self.current_prices = price_dict
            col, desc = self.sort_by
            sorted_items = sorted(price_dict.items(), key=lambda x: x[0] if col == "symbol" else x[1], reverse=desc)
            self.price_tree.delete(*self.price_tree.get_children())

            for symbol, price in sorted_items:
                last_price = self.last_prices.get(symbol, price)
                delta = price - last_price
                color = "black"
                arrow = ""
                if delta > 0:
                    color = "green"
                    arrow = "▲"
                elif delta < 0:
                    color = "red"
                    arrow = "▼"

                self.price_tree.insert("", tk.END, values=(symbol, f"{arrow} ${price:.2f}"), tags=(color,))
                self.last_prices[symbol] = price

            self.price_tree.tag_configure("green", foreground="green")
            self.price_tree.tag_configure("red", foreground="red")
            self.price_tree.tag_configure("black", foreground="black")

        self.after(0, _update)

    def start_monitoring(self):
        self.text_area.insert(tk.END, "Monitoring started...\n")
        if not self.task or self.task.done():
            self.task = asyncio.run_coroutine_threadsafe(main(self.queue), self.loop)

    def stop_monitoring(self):
        if self.task and not self.task.done():
            self.task.cancel()
        self.text_area.insert(tk.END, "Monitoring stopped.\n")

    def process_queue(self):
        while not self.queue.empty():
            item = self.queue.get()
            if isinstance(item, tuple) and item[0] == "__PRICE_UPDATE__":
                _, price_dict, update_time = item
                self.update_label.config(text=f"Last Update: {update_time}")
                self.update_price_table(price_dict)
            else:
                self.text_area.insert(tk.END, item + '\n')
                self.text_area.see(tk.END)
        self.after(100, self.process_queue)

    def on_close(self):
        self.stop_monitoring()
        self.loop.call_soon_threadsafe(self.loop.stop)
        self.destroy()

if __name__ == "__main__":
    app = StockApp()
    app.protocol("WM_DELETE_WINDOW", app.on_close)
    app.mainloop()
