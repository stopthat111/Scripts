import json
import csv
import difflib

# Load Fortune 500 list
with open("fortune500_companies.json", "r") as f:
    fortune500 = json.load(f)

# Load NASDAQ CSV
tickers = []
with open("all_tickers.csv", newline='') as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        tickers.append({
            "symbol": row["Symbol"].strip(),
            "name": row["Name"].strip()
        })

# Match company names
matched = {}
for company in fortune500:
    best_match = difflib.get_close_matches(company, [t["name"] for t in tickers], n=1, cutoff=0.8)
    if best_match:
        for t in tickers:
            if t["name"] == best_match[0]:
                matched[company] = t["symbol"]
                break

# Save to fortune500.json
with open("fortune500.json", "w") as f:
    json.dump(matched, f, indent=4)

print(f"Matched {len(matched)} companies.")
