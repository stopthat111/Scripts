import pandas as pd
import yfinance as yf
import json
import time

def get_fortune_500_companies():
    url = 'https://en.wikipedia.org/wiki/List_of_largest_companies_in_the_United_States_by_revenue'
    try:
        tables = pd.read_html(url)
        df = tables[0]
        if 'Name' in df.columns:
            companies = df['Name'].tolist()
        elif 'Company' in df.columns:
            companies = df['Company'].tolist()
        else:
            raise ValueError("Company name column not found.")
        return companies
    except Exception as e:
        print(f"[ERROR] Failed to fetch table from Wikipedia: {e}")
        return []

def resolve_symbol(company_name):
    try:
        ticker = yf.Ticker(company_name)
        info = ticker.info
        symbol = info.get('symbol', None)
        # Validate that the symbol works by trying to fetch price data
        if symbol:
            test_data = yf.download(symbol, period="1d")
            if not test_data.empty:
                return symbol
    except Exception:
        pass
    return None

def main():
    companies = get_fortune_500_companies()
    print(f"[INFO] Total companies fetched: {len(companies)}")

    symbols = []
    for i, company in enumerate(companies):
        print(f"[INFO] Resolving symbol for {company} ({i+1}/{len(companies)})")
        symbol = resolve_symbol(company)
        if symbol:
            symbols.append(symbol)
            print(f"   ✓ Found symbol: {symbol}")
        else:
            print(f"   ✗ Could not resolve symbol.")
        time.sleep(0.5)  # Be nice to Yahoo's servers

    with open("fortune500.json", "w") as f:
        json.dump(symbols, f, indent=4)
    print(f"[DONE] {len(symbols)} symbols saved to fortune500.json")

if __name__ == "__main__":
    main()
