from worker import Worker

if __name__ == "__main__":
    worker = Worker()
    try:
        worker.run_loop()
    except KeyboardInterrupt:
        print("Worker stopped.")
