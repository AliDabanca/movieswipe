"""
Fix RLS policies on the profiles table.
Uses the service_role key to execute SQL via Supabase's raw SQL endpoint.
"""
import sys, os, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.core.config import settings
import httpx

# Use the REST API to run SQL directly
SUPABASE_URL = settings.supabase_url
SERVICE_ROLE_KEY = settings.supabase_key

headers = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

# Step 1: Check what policies currently exist
print("=== Step 1: Checking current RLS status ===")

# We can check via the Supabase Management API or by querying information_schema
# Let's try a simple test: insert a profile row using service_role (bypasses RLS)
from supabase import create_client
client = create_client(SUPABASE_URL, SERVICE_ROLE_KEY)

# Check current auth users
print("\n=== Step 2: Listing auth users (first 5) ===")
try:
    users_response = client.auth.admin.list_users()
    for u in users_response[:5]:
        uid = u.id[:8] if u.id else "?"
        print(f"  Auth user: {uid}... email={u.email}")
except Exception as e:
    print(f"  Cannot list users: {e}")

# Step 3: Check if there's a profile for current user  
print("\n=== Step 3: Checking profiles vs auth users ===")
try:
    profiles = client.table("profiles").select("id, username").execute()
    profile_ids = set(p["id"] for p in profiles.data)
    print(f"  Profiles in DB: {len(profiles.data)}")
    for p in profiles.data:
        print(f"    - {p['id'][:8]}... username={p.get('username')}")
    
    # Check which auth users DON'T have profiles
    users_response = client.auth.admin.list_users()
    for u in users_response:
        if u.id not in profile_ids:
            print(f"  ⚠️  Auth user {u.id[:8]}... ({u.email}) has NO profile!")
except Exception as e:
    print(f"  Error: {e}")

# Step 4: Try to recreate RLS policies using the SQL endpoint
print("\n=== Step 4: Fixing RLS Policies ===")
sql = """
-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can create their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Recreate policies
CREATE POLICY "Profiles are viewable by everyone"
    ON profiles FOR SELECT
    USING (true);

CREATE POLICY "Users can create their own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);
"""

try:
    # Try via pg_net or direct SQL
    response = httpx.post(
        f"{SUPABASE_URL}/rest/v1/rpc/exec_sql",
        headers=headers,
        json={"query": sql},
        timeout=30.0,
    )
    print(f"  SQL Response: {response.status_code}")
    print(f"  Body: {response.text[:500]}")
except Exception as e:
    print(f"  Direct SQL failed: {e}")
    print("  -> You need to run the SQL manually in Supabase Dashboard")
    print("\n  === SQL to run in Supabase SQL Editor: ===")
    print(sql)
