from database import Database

def reset_jobs():
    db = Database()
    with db.conn.cursor() as cur:
        # Update the broken image URL to a working one (a yellow dress)
        cur.execute("""
            UPDATE item_upload_jobs 
            SET iuj_image_url = 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?q=80&w=1024&auto=format&fit=crop'
            WHERE iuj_image_url = 'https://images.unsplash.com/photo-1596755094514-f87e3406ceb3?q=80&w=1024&auto=format&fit=crop'
        """)
        
        # Reset statuses
        cur.execute("""
            UPDATE item_upload_jobs 
            SET iuj_status = 'PENDING', iuj_retry_count = 0, iuj_last_error = NULL
            WHERE iuj_status = 'FAILED'
        """)
        
        print("All failed jobs reset to PENDING.")
        
    db.close()
        
if __name__ == "__main__":
    reset_jobs()
