import requests
from bs4 import BeautifulSoup
import json

def fetch_fortune_500():
    url = 'https://fortune.com/fortune500/'
    response = requests.get(url)
    soup = BeautifulSoup(response.content, 'html.parser')

    # Find the company names in the Fortune 500 list
    company_names = []
    for company in soup.find_all('div', class_='list__item__title'):
        company_names.append(company.get_text(strip=True))

    # Here, you would normally get the symbols through a different API or process
    # For now, we'll assume that the symbol can be derived by a lookup or manual input for simplicity.
    # You can enhance this later with real-time symbol lookups or a database.
    symbols = []  # You'll need a way to fetch symbols for these companies.
    
    # Placeholder: Assuming the symbols are the same as the company names (change this for actual logic)
    for name in company_names:
        symbol = name[:4].upper()  # Dummy symbol for illustration (first 4 letters of company name)
        symbols.append(symbol)
    
    return symbols

def save_to_json(symbols):
    with open('fortune500.json', 'w') as f:
        json.dump(symbols, f, indent=4)

fortune_500_symbols = fetch_fortune_500()
save_to_json(fortune_500_symbols)

print(f"Fortune 500 symbols saved to fortune500.json")
