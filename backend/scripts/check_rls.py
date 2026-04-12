"""Check profiles table RLS policies and data."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.core.config import settings
from supabase import create_client

client = create_client(settings.supabase_url, settings.supabase_key)

# 1. Check profiles data
print("=== Profiles Table ===")
result = client.table("profiles").select("id, username, created_at").limit(5).execute()
print(f"Found {len(result.data)} profiles:")
for p in result.data:
    uid = p["id"][:8] if p.get("id") else "?"
    print(f"  - {uid}... username={p.get('username')}")

# 2. Check RLS policies via pg_policies
print("\n=== RLS Policies on profiles ===")
try:
    policies = client.from_("pg_policies").select("*").eq("tablename", "profiles").execute()
    for pol in policies.data:
        print(f"  Policy: {pol.get('policyname')}")
        print(f"    Command: {pol.get('cmd')}")
        print(f"    Qual: {pol.get('qual')}")
        print(f"    With Check: {pol.get('with_check')}")
except Exception as e:
    print(f"  Cannot query pg_policies directly: {e}")
    # Try raw SQL via RPC
    try:
        sql_result = client.rpc("exec_sql", {
            "query": "SELECT policyname, cmd, qual, with_check FROM pg_policies WHERE tablename = 'profiles'"
        }).execute()
        print(f"  RPC result: {sql_result.data}")
    except Exception as e2:
        print(f"  RPC also failed: {e2}")
        print("  -> You need to check RLS policies in Supabase Dashboard")

# 3. Test insert with service_role (should bypass RLS)
print("\n=== Service Role Insert Test ===")
import uuid
test_id = str(uuid.uuid4())
print(f"  Attempting insert with test ID: {test_id[:8]}...")
try:
    insert_result = client.table("profiles").insert({
        "id": test_id,
        "username": f"test{test_id[:6]}"
    }).execute()
    print(f"  SUCCESS: Inserted profile for {test_id[:8]}")
    # Clean up
    client.table("profiles").delete().eq("id", test_id).execute()
    print(f"  Cleaned up test profile")
except Exception as e:
    print(f"  FAILED: {e}")
    print("  -> This means even service_role cannot insert, check table schema!")
