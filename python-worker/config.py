import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY")
    NVIDIA_MODEL = os.getenv("NVIDIA_MODEL", "meta/llama-3.2-11b-vision-instruct")
    # No fallback: credentials must come from the environment, never source control.
    DATABASE_URL = os.getenv("DATABASE_URL")
    POLL_INTERVAL_SECONDS = 2
    MAX_RETRIES = 1
