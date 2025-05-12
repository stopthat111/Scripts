import asyncio
import requests
import talib
import pandas as pd
from textblob import TextBlob
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
import numpy as np
import yfinance as yf
import sqlite3
import nio
from datetime import datetime, timedelta

# CONFIGURATION
WATCHLIST = ['AAPL', 'GOOG', 'MSFT', 'AMZN', 'TSLA', 'FB']  # Initial watchlist
RSI_THRESHOLD = 30
MACD_THRESHOLD = 0
SMA_SHORT_PERIOD = 50
SMA_LONG_PERIOD = 200
BOLLINGER_BAND_STDDEV = 2
SMA_CROSSOVER_THRESHOLD = 0.01
STOP_LOSS_PERCENTAGE = 0.02  # 2% stop-loss
TAKE_PROFIT_PERCENTAGE = 0.05  # 5% take-profit
MODEL_TRAINING_DAYS = 365  # Use the last 365 days for model training
MATRIX_HOMESERVER = "https://matrix.org"
MATRIX_USERNAME = "@yourai_bot:matrix.org"
MATRIX_PASSWORD = "yourpassword"
MATRIX_ROOM_ID = "!yourroomid:matrix.org"
SEC_EDGAR_API = "https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK="
DB_FILE = "C:\\Users\\Public\\politician_trades.db"
MIN_TRADE_AMOUNT = 100000  # Filter trades below $100K
VOLUME_SURGE_THRESHOLD = 2  # Volume surge threshold (x average volume)
OPTION_BET_THRESHOLD = 200000  # Minimum premium for big option bets
PRICE_SPIKE_10MIN = 5  # % Change in 10 min for alert
PRICE_SPIKE_1HOUR = 10  # % Change in 1 hour for alert

# Database Setup
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

# Matrix Bot for Alerts
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

# Fetch Unusual Trades from SEC EDGAR API
def fetch_unusual_trades():
    try:
        trades = []
        for stock in WATCHLIST:
            url = f"{SEC_EDGAR_API}{stock}&owner=only&count=10"
            headers = {'User-Agent': 'Mozilla/5.0'}
            response = requests.get(url, headers=headers)
            response.raise_for_status()
            if "FORM TYPE" in response.text:
                trades.append({"ticker": stock, "transaction_type": "Unknown", "premium": MIN_TRADE_AMOUNT})
        return trades
    except requests.exceptions.RequestException as e:
        print(f"Error fetching unusual trades: {e}")
        return []

# Sentiment Analysis for News Headlines
def get_news_sentiment(stock_symbol):
    try:
        url = f'https://newsapi.org/v2/everything?q={stock_symbol}&apiKey=your_api_key'
        response = requests.get(url)
        response.raise_for_status()
        news_data = response.json()
        
        sentiment_score = 0
        for article in news_data['articles']:
            blob = TextBlob(article['title'])
            sentiment_score += blob.sentiment.polarity
        
        sentiment_score = sentiment_score / len(news_data['articles']) if news_data['articles'] else 0
        return sentiment_score
    except requests.exceptions.RequestException as e:
        print(f"Error fetching news sentiment: {e}")
        return 0

# Fetch Fortune 500 or NASDAQ symbols dynamically (Example)
def fetch_fortune_500():
    # Placeholder: Example method to fetch Fortune 500 symbols. Could be an API or a predefined list.
    fortune_500_symbols = ['AAPL', 'MSFT', 'AMZN', 'GOOG', 'TSLA', 'FB']
    return fortune_500_symbols

def fetch_nasdaq_symbols():
    # Example method to fetch NASDAQ symbols (just a placeholder)
    nasdaq_symbols = ['AAPL', 'GOOG', 'MSFT', 'AMZN', 'FB', 'TSLA']
    return nasdaq_symbols

# Update the watchlist dynamically with Fortune 500 or NASDAQ stocks
def update_watchlist():
    fortune_500 = fetch_fortune_500()
    nasdaq = fetch_nasdaq_symbols()
    updated_watchlist = list(set(fortune_500 + nasdaq))  # Combine and remove duplicates
    return updated_watchlist

# Function to fetch stock data
def fetch_stock_data(stock_symbol):
    data = yf.download(stock_symbol, period="1y", interval="1d")
    return data

# Machine Learning Model for Predictive Signals
def train_ml_model(stock_symbol):
    data = yf.download(stock_symbol, period="1y", interval="1d")
    data['RSI'] = talib.RSI(data['Close'].values, timeperiod=14)
    data['MACD'], data['Signal'], _ = talib.MACD(data['Close'].values, fastperiod=12, slowperiod=26, signalperiod=9)
    data['Price Change'] = data['Close'].pct_change().shift(-1)
    data.dropna(inplace=True)
    
    features = data[['RSI', 'MACD', 'Signal']]
    target = np.where(data['Price Change'] > 0, 1, 0)
    X_train, X_test, y_train, y_test = train_test_split(features, target, test_size=0.2, random_state=42)
    
    model = RandomForestClassifier()
    model.fit(X_train, y_train)
    
    accuracy = model.score(X_test, y_test)
    print(f'Model Accuracy: {accuracy * 100}%')
    
    return model

# Calculate Technical Indicators
def get_technical_indicators(stock_data):
    close_prices = stock_data['Close'].values
    sma_short = talib.SMA(close_prices, timeperiod=SMA_SHORT_PERIOD)
    sma_long = talib.SMA(close_prices, timeperiod=SMA_LONG_PERIOD)
    upper_band, middle_band, lower_band = talib.BBANDS(close_prices, timeperiod=20, nbdevup=BOLLINGER_BAND_STDDEV, nbdevdn=BOLLINGER_BAND_STDDEV)
    return sma_short, sma_long, upper_band, lower_band

# Monitor Stock Trades
async def monitor_stocks(bot):
    setup_database()

    # Update Watchlist dynamically
    global WATCHLIST
    WATCHLIST = update_watchlist()

    # Train ML Models
    models = {}
    for stock_symbol in WATCHLIST:
        models[stock_symbol] = train_ml_model(stock_symbol)

    while True:
        for stock_symbol in WATCHLIST:
            stock_data = fetch_stock_data(stock_symbol)
            if stock_data is not None:
                sentiment_score = get_news_sentiment(stock_symbol)
                sma_short, sma_long, upper_band, lower_band = get_technical_indicators(stock_data)
                latest_price = stock_data['Close'].iloc[-1]
                
                # Check Unusual Trades
                trades = fetch_unusual_trades()
                for trade in trades:
                    stock = trade["ticker"]
                    transaction = trade["transaction_type"]
                    amount = trade["premium"]
                    date = datetime.now().strftime("%Y-%m-%d")
                    if trade["premium"] >= OPTION_BET_THRESHOLD:
                        alert_message = f"🚨 BIG OPTION BET: {stock} - {transaction} - ${amount} on {date}"
                        await bot.send_message(alert_message)

                # Moving Average Crossover
                if sma_short[-1] > sma_long[-1]:
                    print("Bullish Signal: Short SMA is above Long SMA")
                elif sma_short[-1] < sma_long[-1]:
                    print("Bearish Signal: Short SMA is below Long SMA")

                # Bollinger Bands
                if latest_price > upper_band[-1]:
                    print("Overbought: Consider selling")
                elif latest_price < lower_band[-1]:
                    print("Oversold: Consider buying")

                # Sentiment-Based Trading Decision
                if sentiment_score > 0.1:
                    print("Positive Sentiment: Consider buying")
                elif sentiment_score < -0.1:
                    print("Negative Sentiment: Consider selling")

                # Use Machine Learning Model for prediction
                features = np.array([stock_data['RSI'][-1], stock_data['MACD'][-1], stock_data['Signal'][-1]]).reshape(1, -1)
                prediction = models[stock_symbol].predict(features)
                if prediction == 1:
                    print("ML Model: Buy Signal")
                else:
                    print("ML Model: Sell Signal")
                
                # Risk Management: Stop-Loss and Take-Profit
                position_size = calculate_position_size(account_balance=100000, stock_price=latest_price, stop_loss_percentage=STOP_LOSS_PERCENTAGE)
                stop_loss_price, take_profit_price = place_stop_loss_and_take_profit(stock_symbol, latest_price, position_size)

                # Price Spike Alerts
                price_change_10min = (stock_data['Close'].iloc[-1] - stock_data['Close'].iloc[-11]) / stock_data['Close'].iloc[-11] * 100
                price_change_1hour = (stock_data['Close'].iloc[-1] - stock_data['Close'].iloc[-61]) / stock_data['Close'].iloc[-61] * 100

                if price_change_10min >= PRICE_SPIKE_10MIN:
                    await bot.send_message(f"🚨 Price Spike (10 minutes): {stock_symbol} changed by {price_change_10min}%")
                
                if price_change_1hour >= PRICE_SPIKE_1HOUR:
                    await bot.send_message(f"🚨 Price Spike (1 hour): {stock_symbol} changed by {price_change_1hour}%")
                
        await asyncio.sleep(60)  # Check every minute

# Risk Management: Position Sizing and Stop-Loss
def calculate_position_size(account_balance, stock_price, stop_loss_percentage):
    risk_per_trade = account_balance * 0.01  # Risk 1% of account balance
    stop_loss_amount = stock_price * stop_loss_percentage
    position_size = risk_per_trade / stop_loss_amount
    return position_size

def place_stop_loss_and_take_profit(stock_symbol, current_price, position_size):
    stop_loss_price = current_price * (1 - STOP_LOSS_PERCENTAGE)
    take_profit_price = current_price * (1 + TAKE_PROFIT_PERCENTAGE)
    print(f"Placing Stop-Loss at {stop_loss_price}, Take-Profit at {take_profit_price}")
    return stop_loss_price, take_profit_price

# Running the Bot
async def main():
    bot = MatrixBot()
    await monitor_stocks(bot)

if __name__ == "__main__":
    asyncio.run(main())
