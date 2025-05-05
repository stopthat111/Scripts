import json
import yfinance as yf
import requests
from bs4 import BeautifulSoup

# Fetch Fortune 500 Companies List
def fetch_fortune_500_companies():
    url = "https://fortune.com/fortune500/"
    response = requests.get(url)
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Extract company names from the page
    companies = []
    for company in soup.select('.result .company-name'):
        companies.append(company.get_text(strip=True))
    
    return companies

# Fetch stock symbols for the Fortune 500 companies
def get_stock_symbols(companies):
    symbols = []
    for company in companies:
        try:
            stock = yf.Ticker(company)
            symbol = stock.info['symbol']
            symbols.append(symbol)
        except:
            print(f"Could not fetch symbol for {company}")
    
    return symbols

# Save the symbols to a JSON file
def save_symbols_to_json(symbols, filename="fortune500.json"):
    with open(filename, 'w') as f:
        json.dump(symbols, f, indent=4)

def main():
    companies = fetch_fortune_500_companies()
    symbols = get_stock_symbols(companies)
    save_symbols_to_json(symbols)
    print(f"Fortune 500 symbols saved to fortune500.json")

if __name__ == "__main__":
    main()
