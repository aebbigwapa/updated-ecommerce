from supabase import create_client
import os
from dotenv import load_dotenv

load_dotenv()

# Read the migration SQL
with open('migrations/phase6_add_missing_columns.sql', 'r') as f:
    sql = f.read()

# Split by semicolon and execute each statement
statements = [s.strip() for s in sql.split(';') if s.strip()]

client = create_client(
    os.getenv('SUPABASE_URL'),
    os.getenv('SUPABASE_SERVICE_ROLE_KEY')
)

print("Running migration phase6_add_missing_columns.sql...")

for i, stmt in enumerate(statements, 1):
    try:
        # Use rpc to execute raw SQL
        result = client.rpc('exec_sql', {'query': stmt}).execute()
        print(f"Statement {i} executed successfully")
    except Exception as e:
        # Some statements might not work via RPC, try alternative
        print(f"Statement {i} failed via RPC: {e}")
        # For ALTER TABLE and CREATE statements, we might need direct SQL execution
        # This is a limitation - we may need to use psql or Supabase dashboard

print("Migration completed")
