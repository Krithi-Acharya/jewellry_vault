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

    @classmethod
    def validate(cls):
        """Fail at startup on missing config, rather than mid-job.

        Without this a missing key surfaces as an auth error deep inside the
        first vision call: the job is retried, marked FAILED, and the item is
        left sitting on the "Uncategorized" placeholder with no obvious cause.
        """
        missing = [
            name for name in ("NVIDIA_API_KEY", "DATABASE_URL")
            if not getattr(cls, name)
        ]
        if missing:
            raise SystemExit(
                "Missing required environment variable(s): "
                + ", ".join(missing)
                + "\nCopy python-worker/.env.example to python-worker/.env and fill in your values."
            )
