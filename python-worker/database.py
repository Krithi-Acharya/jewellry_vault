import psycopg2
from psycopg2.extras import RealDictCursor
import json
import datetime
from config import Config

class Database:
    def __init__(self):
        self.conn = psycopg2.connect(Config.DATABASE_URL)
        self.conn.autocommit = True

    def get_pending_job(self):
        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT * FROM item_upload_jobs 
                WHERE iuj_status = 'PENDING' 
                ORDER BY iuj_created_at ASC 
                LIMIT 1
                FOR UPDATE SKIP LOCKED
            """)
            return cur.fetchone()

    def update_job_status(self, job_id, status, error=None, increment_retry=False):
        with self.conn.cursor() as cur:
            retry_sql = "iuj_retry_count = iuj_retry_count + 1," if increment_retry else ""
            error_val = error if error else None
            processed_sql = "iuj_processed_at = NOW()," if status in ('COMPLETED', 'FAILED') else ""
            
            cur.execute(f"""
                UPDATE item_upload_jobs 
                SET iuj_status = %s,
                    {retry_sql}
                    {processed_sql}
                    iuj_last_error = %s
                WHERE iuj_id = %s
            """, (status, error_val, job_id))

    def save_raw_ai_response(self, ci_id, provider, model, prompt_version, raw_response):
        with self.conn.cursor() as cur:
            cur.execute("""
                INSERT INTO item_ai_responses 
                (iair_ci_id, iair_provider, iair_model, iair_prompt_version, iair_raw_response)
                VALUES (%s, %s, %s, %s, %s)
            """, (ci_id, provider, model, prompt_version, json.dumps(raw_response)))

    def save_extracted_metadata(self, ci_id, colors, attributes):
        # We don't overwrite if manual values exist. This will be a bit complex.
        # For simplicity in MVP, we will try to insert a new row in closet_item_ai_tags 
        # and not modify user attributes unless empty.
        
        with self.conn.cursor() as cur:
            tags = {
                "ai_colors": colors,
                "ai_attributes": attributes
            }
            
            cur.execute("""
                INSERT INTO closet_item_ai_tags (ciaitag_ci_id, ciaitag_tags)
                VALUES (%s, %s)
                ON CONFLICT (ciaitag_ci_id) DO UPDATE SET ciaitag_tags = %s
            """, (ci_id, json.dumps(tags), json.dumps(tags)))
            
    def close(self):
        self.conn.close()
