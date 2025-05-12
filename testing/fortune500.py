import json
import csv
import difflib
import re

# Normalize company name by removing suffixes and converting to lowercase
def normalize(name):
    name = name.lower()
    name = re.sub(r'\b(incorporated|inc|corp|corporation|llc|co|ltd|plc)\b\.?', '', name)
    name = re.sub(r'[^\w\s]', '', name)  # remove punctuation
    return name.strip()

# Load Fortune 500 company names
with open("fortune500_companies.json", "r") as f:
    fortune500 = json.load(f)
normalized_f500 = {normalize(name): name for name in fortune500}

# Load all tickers from CSV
tickers = []
with open("all_tickers.csv", newline='') as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        tickers.append({
            "symbol": row["Symbol"].strip(),
            "name": row["Name"].strip(),
            "normalized": normalize(row["Name"])
        })

# Perform fuzzy matching
matched = {}
for norm_f500, original_f500 in normalized_f500.items():
    best_match = difflib.get_close_matches(norm_f500, [t["normalized"] for t in tickers], n=1, cutoff=0.8)
    if best_match:
        for t in tickers:
            if t["normalized"] == best_match[0]:
                matched[original_f500] = t["symbol"]
                break

# Save matched symbols to JSON
with open("fortune500.json", "w") as f:
    json.dump(matched, f, indent=4)

print(f"Matched {len(matched)} companies.")
