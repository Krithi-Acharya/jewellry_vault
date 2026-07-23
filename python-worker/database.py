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
            
    # The model names garments in its own vocabulary, which does not always
    # match the seeded category rows (it returns "Bottoms"/"Jeans" where the
    # table stores "Pants"). Mapping the common variants avoids fragmenting the
    # category list with a row per phrasing.
    CATEGORY_SYNONYMS = {
        'bottom': 'Pants',
        'bottoms': 'Pants',
        'jeans': 'Pants',
        'denim': 'Pants',
        'trousers': 'Pants',
        'leggings': 'Pants',
        'shorts': 'Pants',
        'blouse': 'Top',
        'tee': 'Top',
        't-shirt': 'Top',
        'tshirt': 'Top',
        'sweater': 'Top',
        'jumper': 'Top',
        'cardigan': 'Top',
        'gown': 'Dress',
        'frock': 'Dress',
        'pendant': 'Necklace',
        'chain': 'Necklace',
        'choker': 'Necklace',
        'locket': 'Necklace',
        'studs': 'Earrings',
        'stud earrings': 'Earrings',
        'hoops': 'Earrings',
        'hoop earrings': 'Earrings',
        'drop earrings': 'Earrings',
        'bangle': 'Bracelet',
        'anklet': 'Bracelet',
        'cuff': 'Bracelet',
        'wristwatch': 'Watch',
        'brooch': 'Accessory',
        'belt': 'Accessory',
        'scarf': 'Accessory',
        'hat': 'Accessory',
        'cap': 'Accessory',
        'sunglasses': 'Accessory',
        'gloves': 'Accessory',
        'handbag': 'Bag',
        'purse': 'Bag',
        'tote': 'Bag',
        'clutch': 'Bag',
        'backpack': 'Bag',
        'coat': 'Outerwear',
        'jacket': 'Outerwear',
        'blazer': 'Outerwear',
        'cardigan sweater': 'Outerwear',
        'sneakers': 'Shoes',
        'boots': 'Shoes',
        'heels': 'Shoes',
        'sandals': 'Shoes',
        'flats': 'Shoes',
    }

    def resolve_category_id(self, *names):
        """Find an item_categories row matching any of the given names.

        Names are tried in order, so callers should pass the most specific
        first. Matching is case-insensitive and tolerates a singular/plural
        mismatch between the model's wording and the seeded rows
        (e.g. "Earring" vs "Earrings").
        """
        with self.conn.cursor() as cur:
            for name in names:
                if not name or not str(name).strip():
                    continue

                base = str(name).strip()
                variants = [base]

                synonym = self.CATEGORY_SYNONYMS.get(base.lower())
                if synonym:
                    variants.append(synonym)

                lowered = base.lower()
                if lowered.endswith('ies'):
                    variants.append(base[:-3] + 'y')   # Accessories -> Accessory
                elif lowered.endswith('s'):
                    variants.append(base[:-1])         # Earrings -> Earring
                else:
                    variants.append(base + 's')        # Earring -> Earrings
                    variants.append(base + 'es')       # Dress -> Dresses

                for variant in variants:
                    cur.execute(
                        "SELECT itc_id FROM item_categories WHERE LOWER(itc_name) = LOWER(%s)",
                        (variant,)
                    )
                    row = cur.fetchone()
                    if row:
                        return row[0]
        return None

    def apply_ai_category(self, ci_id, category, subcategory):
        """Point the item at the category the model actually detected.

        Uploads are created against a placeholder category, so without this the
        item keeps whichever row happened to be first in the table. The
        subcategory is checked first because it carries the specific type the
        categories table stores (e.g. "Necklace" rather than "Jewelry").

        Returns the matched category id, or None when nothing matched - in
        which case the existing category is left untouched.
        """
        category_id = self.resolve_category_id(subcategory, category)
        if category_id is None:
            return None

        with self.conn.cursor() as cur:
            cur.execute(
                "UPDATE closet_items SET ci_category_id = %s WHERE ci_id = %s",
                (category_id, ci_id)
            )
        return category_id

    def close(self):
        self.conn.close()
