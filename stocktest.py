import asyncio
import requests
from finta import TA
import pandas as pd
from textblob import TextBlob
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
import numpy as np
import yfinance as yf
import sqlite3
from datetime import datetime

# CONFIGURATION
WATCHLIST = ['AAPL', 'GOOG', 'MSFT', 'AMZN', 'TSLA', 'FB']
RSI_THRESHOLD = 30
MACD_THRESHOLD = 0
SMA_SHORT_PERIOD = 50
SMA_LONG_PERIOD = 200
BOLLINGER_BAND_STDDEV = 2
SMA_CROSSOVER_THRESHOLD = 0.01
STOP_LOSS_PERCENTAGE = 0.02
TAKE_PROFIT_PERCENTAGE = 0.05
MODEL_TRAINING_DAYS = 365
SEC_EDGAR_API = "https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK="
DB_FILE = "C:\\Users\\Public\\politician_trades.db"
MIN_TRADE_AMOUNT = 100000
VOLUME_SURGE_THRESHOLD = 2
OPTION_BET_THRESHOLD = 200000
PRICE_SPIKE_10MIN = 5
PRICE_SPIKE_1HOUR = 10

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

def fetch_fortune_500():
    return ['AAPL', 'MSFT', 'AMZN', 'GOOG', 'TSLA', 'FB']

def fetch_nasdaq_symbols():
    return ['AAPL', 'GOOG', 'MSFT', 'AMZN', 'FB', 'TSLA']

def update_watchlist():
    return list(set(fetch_fortune_500() + fetch_nasdaq_symbols()))

def fetch_stock_data(stock_symbol):
    data = yf.download(stock_symbol, period="1y", interval="1d")
    return data.rename(columns=str.lower)

def train_ml_model(stock_symbol):
    data = yf.download(stock_symbol, period="1y", interval="1d").rename(columns=str.lower)

    data['RSI'] = TA.RSI(data)
    macd = TA.MACD(data)
    data['MACD'] = macd['MACD']
    data['Signal'] = macd['SIGNAL']
    data['Price Change'] = data['close'].pct_change().shift(-1)
    data.dropna(inplace=True)

    features = data[['RSI', 'MACD', 'Signal']]
    target = np.where(data['Price Change'] > 0, 1, 0)

    X_train, X_test, y_train, y_test = train_test_split(features, target, test_size=0.2, random_state=42)
    model = RandomForestClassifier()
    model.fit(X_train, y_train)
    accuracy = model.score(X_test, y_test)
    print(f'Model Accuracy for {stock_symbol}: {accuracy * 100:.2f}%')
    return model

def get_technical_indicators(stock_data):
    stock_data['SMA_SHORT'] = TA.SMA(stock_data, SMA_SHORT_PERIOD)
    stock_data['SMA_LONG'] = TA.SMA(stock_data, SMA_LONG_PERIOD)
    bb = TA.BBANDS(stock_data)
    return stock_data['SMA_SHORT'], stock_data['SMA_LONG'], bb['BB_UPPER'], bb['BB_LOWER']

async def monitor_stocks():
    setup_database()
    global WATCHLIST
    WATCHLIST = update_watchlist()
    models = {stock: train_ml_model(stock) for stock in WATCHLIST}

    while True:
        for stock_symbol in WATCHLIST:
            stock_data = fetch_stock_data(stock_symbol)
            if stock_data is not None:
                sentiment_score = get_news_sentiment(stock_symbol)
                sma_short, sma_long, upper_band, lower_band = get_technical_indicators(stock_data)
                latest_price = stock_data['close'].iloc[-1]

                for trade in fetch_unusual_trades():
                    if trade["premium"] >= OPTION_BET_THRESHOLD:
                        print(f"🚨 BIG OPTION BET: {trade['ticker']} - {trade['transaction_type']} - ${trade['premium']}")

                if sma_short.iloc[-1] > sma_long.iloc[-1]:
                    print(f"{stock_symbol}: Bullish crossover.")
                elif sma_short.iloc[-1] < sma_long.iloc[-1]:
                    print(f"{stock_symbol}: Bearish crossover.")

                if latest_price > upper_band.iloc[-1]:
                    print(f"{stock_symbol}: Overbought.")
                elif latest_price < lower_band.iloc[-1]:
                    print(f"{stock_symbol}: Oversold.")

                if sentiment_score > 0.1:
                    print(f"{stock_symbol}: Positive Sentiment.")
                elif sentiment_score < -0.1:
                    print(f"{stock_symbol}: Negative Sentiment.")

                features = np.array([stock_data['RSI'].iloc[-1], stock_data['MACD'].iloc[-1], stock_data['Signal'].iloc[-1]]).reshape(1, -1)
                prediction = models[stock_symbol].predict(features)
                print(f"{stock_symbol}: {'Buy' if prediction == 1 else 'Sell'} Signal")

                position_size = calculate_position_size(100000, latest_price, STOP_LOSS_PERCENTAGE)
                stop_loss_price, take_profit_price = place_stop_loss_and_take_profit(stock_symbol, latest_price, position_size)

                try:
                    price_change_10min = (stock_data['close'].iloc[-1] - stock_data['close'].iloc[-11]) / stock_data['close'].iloc[-11] * 100
                    price_change_1hour = (stock_data['close'].iloc[-1] - stock_data['close'].iloc[-61]) / stock_data['close'].iloc[-61] * 100
                    if price_change_10min >= PRICE_SPIKE_10MIN:
                        print(f"🚨 {stock_symbol}: Price up {price_change_10min:.2f}% in 10 minutes")
                    if price_change_1hour >= PRICE_SPIKE_1HOUR:
                        print(f"🚨 {stock_symbol}: Price up {price_change_1hour:.2f}% in 1 hour")
                except IndexError:
                    pass

        await asyncio.sleep(60)

def calculate_position_size(account_balance, stock_price, stop_loss_percentage):
    risk_per_trade = account_balance * 0.01
    stop_loss_amount = stock_price * stop_loss_percentage
    return risk_per_trade / stop_loss_amount

def place_stop_loss_and_take_profit(stock_symbol, current_price, position_size):
    stop_loss_price = current_price * (1 - STOP_LOSS_PERCENTAGE)
    take_profit_price = current_price * (1 + TAKE_PROFIT_PERCENTAGE)
    print(f"{stock_symbol}: Stop-Loss at {stop_loss_price:.2f}, Take-Profit at {take_profit_price:.2f}")
    return stop_loss_price, take_profit_price

async def main():
    await monitor_stocks()

if __name__ == "__main__":
    asyncio.run(main())
