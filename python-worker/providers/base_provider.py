class VisionProvider:
    def analyze(self, image_path: str, prompt_version: str) -> dict:
        """
        Takes an image path and a prompt version, returns a dictionary containing
        the parsed JSON from the LLM, alongside success status and provider info.
        """
        raise NotImplementedError
