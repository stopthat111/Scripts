import requests
from bs4 import BeautifulSoup
import re
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
import time
import logging
from fake_useragent import UserAgent

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

# Request user input for the domain
domain = input("Please enter the domain: ")

# Configure Chrome options
options = Options()
options.add_argument("--headless")
options.add_argument("--disable-blink-features=AutomationControlled")
ua = UserAgent()
options.add_argument(f'user-agent={ua.random}')

# Initialize WebDriver
driver = webdriver.Chrome(options=options)

# Email pattern
email_pattern = r'[\w\.-]+@[\w\.-]+'


# -------------------------
# 1. Search Engine Queries (Google, Bing, DuckDuckGo)
# -------------------------
def search_engine_query(domain, engine):
    try:
        if engine == 'google':
            search_url = f'https://www.google.com/search?q=site:{domain} email'
        elif engine == 'bing':
            search_url = f'https://www.bing.com/search?q=site:{domain} email'
        elif engine == 'duckduckgo':
            search_url = f'https://duckduckgo.com/?q=site:{domain} email'
        else:
            return set()
        
        driver.get(search_url)
        time.sleep(2)
        
        email_addresses = set()
        links = driver.find_elements(By.CSS_SELECTOR, 'a')
        
        for element in links:
            href = element.get_attribute('href')
            if href and 'mailto:' in href:
                email = href[7:]  # Remove "mailto:"
                if re.match(email_pattern, email):
                    email_addresses.add(email)
        
        return email_addresses
    except Exception as e:
        logging.error(f"Error during {engine.capitalize()} search: {e}")
        return set()


# -------------------------
# 2. Recursive Web Scraping
# -------------------------
def scrape_emails_from_website(url, depth=2):
    emails = set()
    visited_urls = set()
    
    def scrape_page(current_url, current_depth):
        if current_depth > depth or current_url in visited_urls:
            return
        visited_urls.add(current_url)
        try:
            headers = {'User-Agent': ua.random}
            response = requests.get(current_url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                soup = BeautifulSoup(response.text, 'html.parser')
                emails.update(set(re.findall(email_pattern, soup.get_text())))
                
                # Find and follow links
                for link in soup.find_all('a', href=True):
                    absolute_link = link['href'] if link['href'].startswith('http') else f'{url.rstrip('/')}/{link['href'].lstrip('/')}'
                    scrape_page(absolute_link, current_depth + 1)
        except Exception as e:
            logging.error(f"Error scraping {current_url}: {e}")
    
    scrape_page(url, 0)
    return emails


# -------------------------
# Main Execution Flow
# -------------------------
logging.info("Starting search engine queries...")

google_emails = search_engine_query(domain, 'google')
bing_emails = search_engine_query(domain, 'bing')
duckduckgo_emails = search_engine_query(domain, 'duckduckgo')

all_search_emails = google_emails.union(bing_emails).union(duckduckgo_emails)
logging.info(f"Found {len(all_search_emails)} email addresses from search engines: {all_search_emails}")

website_url = f'http://{domain}'
logging.info("Starting recursive website scraping...")
emails_from_website = scrape_emails_from_website(website_url)
logging.info(f"Found {len(emails_from_website)} email addresses from website scraping: {emails_from_website}")

# Combine results
all_emails = all_search_emails.union(emails_from_website)
logging.info(f"Total found email addresses: {all_emails}")

# Save to file
with open("emails.txt", "w") as f:
    for email in all_emails:
        f.write(email + "\n")

logging.info("Script execution completed.")
driver.quit()
