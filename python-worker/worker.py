import os
import requests
import time
import logging
from PIL import Image, ExifTags
from config import Config
from database import Database
from providers.nvidia_provider import NvidiaNimProvider

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

class Worker:
    def __init__(self):
        self.db = Database()
        self.vision_provider = NvidiaNimProvider(api_key=Config.NVIDIA_API_KEY, model=Config.NVIDIA_MODEL)

        
        # Ensure temp directory exists
        self.temp_dir = os.path.join(os.path.dirname(__file__), "temp")
        os.makedirs(self.temp_dir, exist_ok=True)

    def _download_and_preprocess(self, url: str, job_id: int) -> str:
        t0 = time.time()
        
        if url.startswith('/'):
            url = f"http://localhost:5000{url}"

        # 1. Download
        local_path = os.path.join(self.temp_dir, f"job_{job_id}_raw.jpg")
        response = requests.get(url, stream=True)
        response.raise_for_status()
        with open(local_path, 'wb') as f:
            for chunk in response.iter_content(8192):
                f.write(chunk)
        t_download = (time.time() - t0) * 1000
        
        t1 = time.time()
        # 2. EXIF Correction, Resize, RGB, Compress
        processed_path = os.path.join(self.temp_dir, f"job_{job_id}_processed.jpg")
        
        with Image.open(local_path) as img:
            # EXIF Orientation
            try:
                for orientation in ExifTags.TAGS.keys():
                    if ExifTags.TAGS[orientation] == 'Orientation':
                        break
                exif = img._getexif()
                if exif is not None and orientation in exif:
                    if exif[orientation] == 3:
                        img = img.rotate(180, expand=True)
                    elif exif[orientation] == 6:
                        img = img.rotate(270, expand=True)
                    elif exif[orientation] == 8:
                        img = img.rotate(90, expand=True)
            except Exception as e:
                pass # EXIF might not exist
            
            # RGB Conversion
            if img.mode != 'RGB':
                img = img.convert('RGB')
                
            # Resize 1024px longest side
            max_size = 1024
            ratio = min(max_size / img.size[0], max_size / img.size[1])
            if ratio < 1.0:
                new_size = (int(img.size[0] * ratio), int(img.size[1] * ratio))
                img = img.resize(new_size, Image.Resampling.LANCZOS)
                
            # Save compressed
            img.save(processed_path, 'JPEG', quality=85)
            
        t_preprocess = (time.time() - t1) * 1000
        
        return processed_path, t_download, t_preprocess

    def process_job(self, job):
        job_id = job['iuj_id']
        ci_id = job['iuj_ci_id']
        image_url = job['iuj_image_url']
        retry_count = job['iuj_retry_count'] or 0
        
        if not image_url:
            self.db.update_job_status(job_id, 'FAILED', 'No image URL provided')
            return
            
        logging.info(f"Processing Job {job_id} (Item {ci_id})")
        
        try:
            self.db.update_job_status(job_id, 'PROCESSING')
            
            # 1. Download & Preprocess
            processed_path, t_download, t_preprocess = self._download_and_preprocess(image_url, job_id)
            
            # (Removed K-Means)

            
            # 3. Vision API
            self.db.update_job_status(job_id, 'ANALYZING')
            t3 = time.time()
            analysis_result = self.vision_provider.analyze(processed_path, prompt_version="metadata_v2")
            t_vision = (time.time() - t3) * 1000
            
            # 4. Save Raw Response
            t4 = time.time()
            self.db.save_raw_ai_response(
                ci_id=ci_id,
                provider=analysis_result.get('provider'),
                model=analysis_result.get('model'),
                prompt_version=analysis_result.get('prompt_version'),
                raw_response=analysis_result.get('raw')
            )
            
            # 5. Validation & Confidence
            if not analysis_result['success']:
                raise ValueError(f"AI Validation failed: {analysis_result.get('error')}")
                
            ai_data = analysis_result['validated']
            
            # Composite Confidence
            # E.g. If it says it's confident but gave us 'null' for category, penalize it
            final_confidence = ai_data.get('confidence', 0.0)
            if not ai_data.get('category'):
                final_confidence *= 0.5
                
            # Thresholding rules (we save it in DB, let the recommendation engine use or ignore based on threshold)
            ai_data['final_confidence'] = final_confidence
            
            # 6. Extract colors from AI Data for DB
            colors = []
            if ai_data.get('primary_color'):
                colors.append(ai_data['primary_color'])
                del ai_data['primary_color']
            if ai_data.get('secondary_color'):
                colors.append(ai_data['secondary_color'])
                del ai_data['secondary_color']
                
            self.db.save_extracted_metadata(ci_id, colors, ai_data)
            
            self.db.update_job_status(job_id, 'COMPLETED')
            t_db = (time.time() - t4) * 1000
            
            # Clean up temp file
            if os.path.exists(processed_path):
                os.remove(processed_path)
            
            # Print timings
            logging.info(f"Job {job_id} Completed")
            logging.info(f"Download ........ {t_download:.0f} ms")
            logging.info(f"Preprocess ...... {t_preprocess:.0f} ms")
            logging.info(f"Vision API ...... {t_vision:.0f} ms")
            logging.info(f"DB Save ......... {t_db:.0f} ms")
            logging.info(f"Total ........... {t_download + t_preprocess + t_vision + t_db:.0f} ms")
            
        except Exception as e:
            logging.error(f"Job {job_id} Failed: {str(e)}")
            if retry_count < Config.MAX_RETRIES:
                self.db.update_job_status(job_id, 'PENDING', str(e), increment_retry=True)
            else:
                self.db.update_job_status(job_id, 'FAILED', str(e))
                
    def run_loop(self):
        logging.info("Starting Python worker polling loop...")
        while True:
            job = self.db.get_pending_job()
            if job:
                self.process_job(job)
            else:
                time.sleep(Config.POLL_INTERVAL_SECONDS)
