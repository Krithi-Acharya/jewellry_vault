from database import Database
import datetime

# Some sample clothing images from Unsplash or Wikimedia to test extraction
TEST_IMAGES = [
    # A black cocktail dress
    "https://images.unsplash.com/photo-1566150905458-1bf1fc113f0d?q=80&w=1024&auto=format&fit=crop",
    # A casual blue denim jacket
    "https://images.unsplash.com/photo-1576995853123-5a10305d93c0?q=80&w=1024&auto=format&fit=crop",
    # Red high heels
    "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?q=80&w=1024&auto=format&fit=crop",
    # A white men's button down shirt
    "https://images.unsplash.com/photo-1596755094514-f87e3406ceb3?q=80&w=1024&auto=format&fit=crop"
]

def seed_jobs():
    db = Database()
    
    # Ensure a dummy user exists
    with db.conn.cursor() as cur:
        cur.execute("""
            INSERT INTO users (usr_email, usr_firebase_uid) 
            VALUES ('test_seed@example.com', 'dummy_uid_123') 
            ON CONFLICT (usr_email) DO UPDATE SET usr_email=EXCLUDED.usr_email
            RETURNING usr_id
        """)
        usr_id = cur.fetchone()[0]
        
    for i, url in enumerate(TEST_IMAGES, start=1):
        try:
            with db.conn.cursor() as cur:
                # Create a dummy closet item
                cur.execute("""
                    INSERT INTO closet_items (ci_usr_id, ci_category_id, ci_status)
                    VALUES (%s, 1, 'ACTIVE') RETURNING ci_id
                """, (usr_id,))
                ci_id = cur.fetchone()[0]
                
                # Create an upload job
                cur.execute("""
                    INSERT INTO item_upload_jobs (iuj_ci_id, iuj_status, iuj_image_url)
                    VALUES (%s, 'PENDING', %s)
                """, (ci_id, url))
                
            print(f"Seeded job for image {i} with closet item ID {ci_id}")
            
        except Exception as e:
            print(f"Failed to seed image {i}: {e}")
            
    db.close()
    
if __name__ == "__main__":
    seed_jobs()
