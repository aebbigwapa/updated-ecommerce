"""
backup_service.py — Database backup and restore for admin.
Exports all critical tables to a .sql file stored in Supabase Storage.
"""
import os
import json
import uuid
from datetime import datetime, timezone
from supabase import create_client


BACKUP_TABLES = [
    'users', 'addresses', 'applications', 'application_documents',
    'products', 'product_variants', 'product_images',
    'orders', 'order_items', 'reviews', 'notifications',
    'admin_settings', 'rider_earnings', 'audit_logs',
]

BACKUP_BUCKET = 'backups'


class BackupService:
    def __init__(self):
        self.sb = create_client(
            os.getenv('SUPABASE_URL'),
            os.getenv('SUPABASE_SERVICE_ROLE_KEY')
        )

    def _rows_to_sql(self, table: str, rows: list) -> str:
        """Convert rows to INSERT SQL statements."""
        if not rows:
            return f'-- {table}: no rows\n'
        lines = [f'-- {table} ({len(rows)} rows)']
        lines.append(f'TRUNCATE TABLE {table} RESTART IDENTITY CASCADE;')
        cols = ', '.join(rows[0].keys())
        for row in rows:
            vals = []
            for v in row.values():
                if v is None:
                    vals.append('NULL')
                elif isinstance(v, bool):
                    vals.append('TRUE' if v else 'FALSE')
                elif isinstance(v, (int, float)):
                    vals.append(str(v))
                elif isinstance(v, (dict, list)):
                    escaped = json.dumps(v, default=str).replace("'", "''")
                    vals.append(f"'{escaped}'")
                else:
                    escaped = str(v).replace("'", "''")
                    vals.append(f"'{escaped}'")
            lines.append(f"INSERT INTO {table} ({cols}) VALUES ({', '.join(vals)});")
        return '\n'.join(lines) + '\n'

    def _get_schema_sql(self) -> str:
        """Read schema.sql from disk, stripping the ALTER-only migration block."""
        schema_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'schema.sql')
        try:
            with open(schema_path, 'r', encoding='utf-8') as f:
                content = f.read()
            # Strip the commented-out ALTER migration block at the bottom
            cut = content.find('-- ============================================\n-- ALTER-ONLY MIGRATION BLOCK')
            if cut != -1:
                content = content[:cut].rstrip()
            return content
        except Exception as e:
            return f'-- WARNING: Could not read schema.sql: {e}'

    def create_backup(self, triggered_by: str = 'admin', notes: str = '') -> dict:
        """
        Export schema + all critical tables to a .sql file and upload to Supabase Storage.
        Returns backup metadata dict.
        """
        backup_id  = str(uuid.uuid4())
        started_at = datetime.now(timezone.utc)
        row_counts = {}

        errors = []
        sql_parts = [
            f'-- Grande E-Commerce Database Backup',
            f'-- Generated: {started_at.isoformat()}',
            f'-- Triggered by: {triggered_by}',
            f'-- Notes: {notes or "none"}',
            f'-- Backup ID: {backup_id}',
            f'-- To restore: psql -U <user> -d <dbname> -f <this_file>',
            '',
            '-- ============================================================',
            '-- STEP 1: SCHEMA (tables, indexes, policies)',
            '-- ============================================================',
            self._get_schema_sql(),
            '',
            '-- ============================================================',
            '-- STEP 2: DATA',
            '-- ============================================================',
            'BEGIN;',
            '',
        ]

        for table in BACKUP_TABLES:
            try:
                rows = self._export_table(table)
                row_counts[table] = len(rows)
                sql_parts.append(self._rows_to_sql(table, rows))
            except Exception as e:
                errors.append(f'{table}: {e}')
                row_counts[table] = 0
                sql_parts.append(f'-- ERROR exporting {table}: {e}\n')

        sql_parts.append('COMMIT;')
        total_rows = sum(row_counts.values())

        sql_bytes  = '\n'.join(sql_parts).encode('utf-8')
        file_size  = len(sql_bytes)
        ts         = started_at.strftime('%Y%m%d_%H%M%S')
        file_name  = f'backup_{ts}_{backup_id[:8]}.sql'
        storage_path = f'db_backups/{file_name}'

        # Upload to Supabase Storage
        storage_error = None
        try:
            try:
                self.sb.storage.create_bucket(BACKUP_BUCKET, options={'public': False})
            except Exception:
                pass  # Bucket already exists
            self.sb.storage.from_(BACKUP_BUCKET).upload(
                path=storage_path,
                file=sql_bytes,
                file_options={'content-type': 'text/plain', 'upsert': 'true'}
            )
            file_url = self.sb.storage.from_(BACKUP_BUCKET).get_public_url(storage_path)
        except Exception as e:
            file_url = None
            storage_error = f'Storage upload failed: {e}'
            print(f'[BackupService] {storage_error}')

        # Save backup record to DB
        record = {
            'id':           backup_id,
            'file_name':    file_name,
            'storage_path': storage_path,
            'file_url':     file_url,
            'file_size_kb': round(file_size / 1024, 2),
            'total_rows':   total_rows,
            'row_counts':   json.dumps(row_counts),
            'triggered_by': triggered_by,
            'notes':        notes,
            'status':       'failed' if (errors or storage_error) else 'success',
            'errors':       json.dumps(errors + ([storage_error] if storage_error else [])) if (errors or storage_error) else None,
        }
        try:
            self.sb.table('backup_history').insert(record).execute()
        except Exception as e:
            pass

        return {
            'success':      not storage_error,
            'backup_id':    backup_id,
            'file_name':    file_name,
            'file_url':     file_url,
            'file_size_kb': record['file_size_kb'],
            'total_rows':   total_rows,
            'row_counts':   row_counts,
            'errors':       errors,
            'created_at':   started_at.isoformat(),
        }

    def get_backup_history(self, limit: int = 20) -> list:
        """Return list of past backups from backup_history table."""
        try:
            r = self.sb.table('backup_history').select('*').order('created_at', desc=True).limit(limit).execute()
            return r.data or []
        except Exception:
            return []

    def delete_backup(self, backup_id: str) -> bool:
        """Delete a backup record and its file from storage."""
        try:
            r = self.sb.table('backup_history').select('storage_path').eq('id', backup_id).limit(1).execute()
            if r.data:
                path = r.data[0].get('storage_path')
                if path:
                    try:
                        self.sb.storage.from_(BACKUP_BUCKET).remove([path])
                    except Exception:
                        pass
            self.sb.table('backup_history').delete().eq('id', backup_id).execute()
            return True
        except Exception:
            return False

    def get_download_url(self, backup_id: str) -> str | None:
        """Get a signed download URL for a backup file."""
        try:
            r = self.sb.table('backup_history').select('storage_path').eq('id', backup_id).limit(1).execute()
            if not r.data:
                return None
            path = r.data[0].get('storage_path')
            if not path:
                return None
            signed = self.sb.storage.from_(BACKUP_BUCKET).create_signed_url(path, expires_in=300)
            return signed.get('signedURL') or signed.get('signedUrl')
        except Exception:
            return None

    def _export_table(self, table: str) -> list:
        """Export all rows from a table in batches of 1000."""
        all_rows = []
        offset   = 0
        batch    = 1000
        while True:
            r = self.sb.table(table).select('*').range(offset, offset + batch - 1).execute()
            rows = r.data or []
            all_rows.extend(rows)
            if len(rows) < batch:
                break
            offset += batch
        return all_rows
