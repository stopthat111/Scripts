import requests
import sqlite3
import nio
import asyncio
from datetime import datetime, timedelta
from bs4 import BeautifulSoup
import yfinance as yf

# CONFIGURATION
MATRIX_HOMESERVER = "https://matrix.org"
MATRIX_USERNAME = "@yourbot:matrix.org"
MATRIX_PASSWORD = "yourpassword"
MATRIX_ROOM_ID = "!yourroomid:matrix.org"
UNUSUAL_WHALES_API = "your_unusual_whales_api"
DB_FILE = "C:\\Users\\Public\\politician_trades.db"
MIN_TRADE_AMOUNT = 100000  # Filter trades below $100K
VOLUME_SURGE_THRESHOLD = 2  # Volume surge threshold (x average volume)
OPTION_BET_THRESHOLD = 200000  # Minimum premium for big option bets
PRICE_SPIKE_10MIN = 5  # % Change in 10 min for alert
PRICE_SPIKE_1HOUR = 10  # % Change in 1 hour for alert

WATCHLIST = [
    "AAPL", "MSFT", "NVDA", "TSLA", "AMZN", "GOOGL", "META",
    "JPM", "BAC", "XOM", "LMT", "RTX", "UNH", "JNJ", "WMT", "HD", "COST"
]

price_history_10min = {}  # Stores price data for 10 min tracking
price_history_1hour = {}  # Stores price data for 1 hour tracking

def setup_database():
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS trades (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        stock TEXT,
                        transaction TEXT,
                        amount INTEGER,
                        date TEXT)''')
    conn.commit()
    conn.close()

def fetch_unusual_trades():
    url = f"https://api.unusualwhales.com/v1/options?api_key={UNUSUAL_WHALES_API}"
    response = requests.get(url)
    if response.status_code == 200:
        trades = response.json()
        return [t for t in trades if t["premium"] >= MIN_TRADE_AMOUNT]
    return []

def fetch_stock_data(ticker):
    stock = yf.Ticker(ticker)
    data = stock.history(period="1h", interval="1m")  # Get last 1 hour data
    return data if not data.empty else None

def check_volume_surge(ticker, current_volume, average_volume):
    if current_volume > average_volume * VOLUME_SURGE_THRESHOLD:
        return True
    return False

def check_large_option_bet(option_trade):
    if option_trade["premium"] >= OPTION_BET_THRESHOLD:
        return True
    return False

class MatrixBot:
    def __init__(self):
        self.client = nio.AsyncClient(MATRIX_HOMESERVER, MATRIX_USERNAME)
        self.logged_in = False

    async def login(self):
        if not self.logged_in:
            await self.client.login(MATRIX_PASSWORD)
            self.logged_in = True

    async def send_message(self, message):
        await self.client.room_send(
            room_id=MATRIX_ROOM_ID,
            message_type="m.room.message",
            content={"msgtype": "m.text", "body": message}
        )

    async def logout(self):
        await self.client.logout()
        self.logged_in = False

async def monitor_trades(bot):
    setup_database()

    while True:
        await bot.login()

        # Check Unusual Whales trades
        trades = fetch_unusual_trades()
        for trade in trades:
            stock = trade["ticker"]
            transaction = trade["transaction_type"]
            amount = trade["premium"]
            date = datetime.now().strftime("%Y-%m-%d")
            if check_large_option_bet(trade):  # Check for big option bets
                alert_message = f"🚨 BIG OPTION BET: {stock} - {transaction} - ${amount} on {date}"
                await bot.send_message(alert_message)

        # Check real-time stock prices & detect spikes
        for stock in WATCHLIST:
            data = fetch_stock_data(stock)
            if data is not None:
                price = data["Close"].iloc[-1]
                volume = data["Volume"].iloc[-1]
                average_volume = data["Volume"].mean()

                now = datetime.now()

                # Track 10-minute price changes
                if stock in price_history_10min:
                    old_time, old_price = price_history_10min[stock]
                    if (now - old_time).seconds >= 600:  # 10 min passed
                        change_10min = ((price - old_price) / old_price) * 100
                        if abs(change_10min) >= PRICE_SPIKE_10MIN:
                            direction = "📈 SPIKE" if change_10min > 0 else "📉 DROP"
                            alert_message = f"{direction}: {stock} moved {change_10min:.2f}% in 10 min! Current price: ${price}"
                            await bot.send_message(alert_message)

                # Track 1-hour price changes
                if stock in price_history_1hour:
                    old_time, old_price = price_history_1hour[stock]
                    if (now - old_time).seconds >= 3600:  # 1 hour passed
                        change_1hour = ((price - old_price) / old_price) * 100
                        if abs(change_1hour) >= PRICE_SPIKE_1HOUR:
                            direction = "📈 BIG SPIKE" if change_1hour > 0 else "📉 BIG DROP"
                            alert_message = f"{direction}: {stock} moved {change_1hour:.2f}% in 1 hour! Current price: ${price}"
                            await bot.send_message(alert_message)

                # Check for volume surges
                if check_volume_surge(stock, volume, average_volume):
                    alert_message = f"🚨 VOLUME SURGE: {stock} saw a volume spike: {volume} shares traded (Avg: {average_volume})"
                    await bot.send_message(alert_message)

                # Update price history
                price_history_10min[stock] = (now, price)
                price_history_1hour[stock] = (now, price)

        await asyncio.sleep(30)  # Check every 30 seconds

async def main():
    bot = MatrixBot()
    await monitor_trades(bot)

if __name__ == "__main__":
    asyncio.run(main())
