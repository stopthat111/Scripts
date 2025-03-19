import requests
from bs4 import BeautifulSoup
import re
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
import time
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

# Request user input for the domain
domain = input("Please enter the domain: ")

# Set up Chrome options for headless browsing (optional)
options = Options()
options.headless = True  # Set to True for headless mode (run without opening a browser window)

# Initialize the WebDriver
driver = webdriver.Chrome(options=options)  # You can replace Chrome() with Firefox() if desired

# Define a regular expression to validate email format
email_pattern = r'[\w\.-]+@[\w\.-]+'  # Simple pattern for matching emails


# -------------------------
# 1. Google Dorks Search
# -------------------------

def google_dorks_search(domain):
    search_query = f"site:{domain} email"
    search_url = f'https://www.google.com/search?q={search_query}'
    driver.get(search_url)
    time.sleep(2)  # Wait for the page to load

    # Collect email addresses from the search results
    email_addresses = set()
    
    # Extract email addresses from search result links
    links = driver.find_elements(By.CSS_SELECTOR, 'a')
    
    for element in links:
        href = element.get_attribute('href')
        if href and 'mailto:' in href:
            email = href[7:]  # Remove "mailto:" part of the href
            if re.match(email_pattern, email):
                email_addresses.add(email)

    return email_addresses

# -------------------------
# 2. BeautifulSoup Web Scraping (direct website scraping)
# -------------------------

def scrape_emails_from_website(url):
    try:
        response = requests.get(url)
        soup = BeautifulSoup(response.text, 'html.parser')
        emails = set(re.findall(email_pattern, soup.get_text()))
        return emails
    except Exception as e:
        logging.error(f"Error scraping {url}: {e}")
        return set()


# -------------------------
# Main Execution Flow
# -------------------------

# 1. Use Google Dorks to search for emails related to the domain
logging.info("Starting Google Dorks search...")
emails_from_dorks = google_dorks_search(domain)
logging.info(f"Found {len(emails_from_dorks)} email addresses via Google Dorks: {emails_from_dorks}")


# 2. Scrape the main domain website for email addresses
website_url = f'http://{domain}'  # Replace with specific URL if needed
logging.info("Starting website scraping...")
emails_from_website = scrape_emails_from_website(website_url)
logging.info(f"Found {len(emails_from_website)} email addresses from website scraping: {emails_from_website}")

# Combine all found emails
all_emails = emails_from_dorks.union(emails_from_website)
if linkedin_email:
    all_emails.add(linkedin_email)

logging.info(f"Total found email addresses: {all_emails}")

# Optionally save the emails to a file
with open("emails.txt", "w") as f:
    for email in all_emails:
        f.write(email + "\n")

logging.info("Script execution completed.")

# Close the browser window
driver.quit()
