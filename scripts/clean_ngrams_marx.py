import pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_DATA = ROOT / "data" / "raw" / "ngram_raw_marx.csv"
PROCESSED_DATA = ROOT / "data" / "processed" / "ngram_clean_marx.csv"

# Load raw data
df = pd.read_csv(ROOT / "data" / "raw" / "ngram_raw_marx.csv", index_col="year")

# 1. Confirm index is integer years
df.index = df.index.astype(int)

# 2. Fill any NaN with 0 — true absence in corpus
df = df.fillna(0)

# 3. Restrict to analysis window
df = df.loc[1878:1932]

# 4. Rename columns cleanly if needed
df.columns = df.columns.str.strip()

# 5. Save
df.to_csv(ROOT / "data" / "processed" / "ngram_clean_marx.csv")
print("Cleaned data saved.")
print(df.shape)
print(df.describe())
