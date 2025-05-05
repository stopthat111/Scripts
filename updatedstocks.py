import tkinter as tk
from tkinter import ttk
from tkinter.scrolledtext import ScrolledText
import asyncio
import threading
import queue
import yfinance as yf
import numpy as np
import pandas as pd
import json
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split

# -- CONFIGURATION --
SMA_SHORT_PERIOD = 50
SMA_LONG_PERIOD = 200
STOP_LOSS_PERCENTAGE = 0.02
TAKE_PROFIT_PERCENTAGE = 0.05
FETCH_INTERVAL_SECONDS = 60
PRICE_PRINT_INTERVAL_SECONDS = 3600

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

# -- Load Symbols from JSON --
def load_fortune500_symbols():
    try:
        with open("fortune500_companies.json", "r") as f:
            data = json.load(f)
            return [entry["symbol"] for entry in data if entry.get("symbol")]
    except Exception as e:
        print(f"Failed to load symbols: {e}")
        return []

# -- Async Monitoring Logic --
async def main(queue_out, status_callback):
    watchlist = load_fortune500_symbols()[:20]
    models = {}

    for symbol in watchlist:
        model = train_ml_model(symbol)
        if model:
            models[symbol] = model

    async def monitor_loop():
        while True:
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

            await asyncio.sleep(FETCH_INTERVAL_SECONDS)

    async def print_prices_hourly():
        while True:
            for symbol in models:
                data = fetch_stock_data(symbol)
                if not data.empty:
                    price = data['Close'].iloc[-1]
                    queue_out.put(f"{symbol} current price: ${price:.2f}")
            if status_callback:
                next_fetch = pd.Timestamp.now() + pd.Timedelta(seconds=PRICE_PRINT_INTERVAL_SECONDS)
                status_callback(f"Next hourly price check: {next_fetch.strftime('%H:%M:%S')}")
            await asyncio.sleep(PRICE_PRINT_INTERVAL_SECONDS)

    await asyncio.gather(monitor_loop(), print_prices_hourly())

# -- GUI Class --
class StockApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Fortune 500 Stock Monitor")
        self.geometry("960x680")  # Slightly larger window

        self.queue = queue.Queue()
        self.loop = asyncio.new_event_loop()
        self.task = None
        self.loop_thread = threading.Thread(target=self.loop.run_forever, daemon=True)
        self.loop_thread.start()

        self.setup_ui()
        self.after(100, self.process_queue)

    def setup_ui(self):
        ttk.Label(self, text="Monitoring Fortune 500 Stocks").pack(pady=10)
        self.text_area = ScrolledText(self, height=30)
        self.text_area.pack(padx=10, pady=10, fill=tk.BOTH, expand=True)

        self.status_label = ttk.Label(self, text="Status: Idle")
        self.status_label.pack(pady=5)

        ttk.Button(self, text="Start Monitoring", command=self.start_monitoring).pack(pady=5)
        ttk.Button(self, text="Stop Monitoring", command=self.stop_monitoring).pack(pady=5)

    def start_monitoring(self):
        self.text_area.insert(tk.END, "Monitoring started...\n")
        if not self.task or self.task.done():
            self.task = asyncio.run_coroutine_threadsafe(main(self.queue, self.update_status), self.loop)

    def stop_monitoring(self):
        if self.task and not self.task.done():
            self.task.cancel()
        self.update_status("Idle")
        self.text_area.insert(tk.END, "Monitoring stopped.\n")

    def process_queue(self):
        while not self.queue.empty():
            msg = self.queue.get()
            self.text_area.insert(tk.END, msg + '\n')
            self.text_area.see(tk.END)
        self.after(100, self.process_queue)

    def update_status(self, message):
        self.status_label.config(text=f"Status: {message}")

    def on_close(self):
        self.stop_monitoring()
        self.loop.call_soon_threadsafe(self.loop.stop)
        self.destroy()

if __name__ == "__main__":
    app = StockApp()
    app.protocol("WM_DELETE_WINDOW", app.on_close)
    app.mainloop()
