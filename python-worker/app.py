from config import Config
from worker import Worker

if __name__ == "__main__":
    Config.validate()
    worker = Worker()
    try:
        worker.run_loop()
    except KeyboardInterrupt:
        print("Worker stopped.")
