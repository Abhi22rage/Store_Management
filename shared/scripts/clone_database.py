"""
Database Data Migration Script: Old Supabase -> New Supabase
Clones 'branches' and 'store_settings' only.
Usage: python shared/scripts/clone_database.py
"""

import sys
import json
import urllib.request
import urllib.error

# Ensure stdout supports UTF-8 on Windows
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

# Old / Production Supabase credentials
OLD_URL = "https://blqolrbpuqjiihfqjriy.supabase.co"
OLD_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJscW9scmJwdXFqaWloZnFqcml5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ4MTIwMjUsImV4cCI6MjA5MDM4ODAyNX0"
    ".M_F6wfoLEFej-KAY5RumBL50MVDab0zqvm5oODlZeB4"
)

# New / Development Supabase credentials
NEW_URL = "https://xrbokywhcabxjrssgdbg.supabase.co"
NEW_KEY = "sb_publishable_waxNVG9ZlQFfO0HWXtpr0Q_k7EBglo-"

# Only clone branches and store_settings
TABLES_TO_MIGRATE = [
    "branches",
    "store_settings",
]

def fetch_table(table_name: str):
    url = f"{OLD_URL}/rest/v1/{table_name}?select=*"
    req = urllib.request.Request(
        url,
        headers={
            "apikey": OLD_KEY,
            "Authorization": f"Bearer {OLD_KEY}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data
    except urllib.error.HTTPError as e:
        print(f"  [WARN] Warning fetching {table_name}: HTTP {e.code} ({e.reason})")
        return []
    except Exception as e:
        print(f"  [ERROR] Error fetching {table_name}: {e}")
        return []

def insert_table(table_name: str, rows: list):
    if not rows:
        print(f"  [INFO] No rows to migrate for table: {table_name}")
        return
    
    url = f"{NEW_URL}/rest/v1/{table_name}"
    payload = json.dumps(rows).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "apikey": NEW_KEY,
            "Authorization": f"Bearer {NEW_KEY}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            print(f"  [OK] Successfully migrated {len(rows)} row(s) into '{table_name}'")
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode('utf-8', errors='ignore')
        print(f"  [ERROR] Error inserting into '{table_name}': HTTP {e.code} - {err_msg}")
    except Exception as e:
        print(f"  [ERROR] Unexpected error inserting into '{table_name}': {e}")

def main():
    print("=" * 60)
    print("SUPABASE DATA CLONER (Branches & Store Settings Only)")
    print(f"From: {OLD_URL}")
    print(f"To:   {NEW_URL}")
    print("=" * 60)

    for table in TABLES_TO_MIGRATE:
        print(f"\nMigrating table: {table}...")
        rows = fetch_table(table)
        if rows:
            print(f"  Found {len(rows)} record(s) in source.")
            insert_table(table, rows)
        else:
            print("  0 records found or table is empty.")

    print("\n" + "=" * 60)
    print("Migration finished!")
    print("=" * 60)

if __name__ == "__main__":
    main()
