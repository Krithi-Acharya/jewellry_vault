import os
import json
import base64
import logging
from openai import OpenAI
from pydantic import ValidationError
import sys

# Add the parent directory to sys.path so we can import from models
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from models import ApparelMetadata
from .base_provider import VisionProvider

class KimiProvider(VisionProvider):
    def __init__(self, api_key: str, model: str):
        self.client = OpenAI(
            api_key=api_key,
            base_url="https://integrate.api.nvidia.com/v1"
        )
        self.model = model

    def _encode_image(self, image_path):
        with open(image_path, "rb") as image_file:
            return base64.b64encode(image_file.read()).decode('utf-8')

    def _load_prompt(self, version):
        prompt_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "prompts", f"{version}.txt")
        with open(prompt_path, "r") as f:
            return f.read()

    def analyze(self, image_path: str, prompt_version: str = "metadata_v1"):
        prompt_text = self._load_prompt(prompt_version)
        base64_image = self._encode_image(image_path)

        messages = [
            {
                "role": "system",
                "content": "Return ONLY valid JSON. No markdown formatting, NO explanations."
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "text", 
                        "text": prompt_text
                    },
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{base64_image}"
                        }
                    }
                ]
            }
        ]

        try:
            # Call NVIDIA API (Kimi K2.6)
            chat_completion = self.client.chat.completions.create(
                messages=messages,
                model=self.model,
                temperature=0.0,
                max_tokens=1024
            )
            
            raw_content = chat_completion.choices[0].message.content
            
            # Clean up potential markdown code blocks returned by some models
            if raw_content.startswith("```json"):
                raw_content = raw_content[7:]
            if raw_content.endswith("```"):
                raw_content = raw_content[:-3]
            raw_content = raw_content.strip()

            # Parse JSON
            parsed_json = json.loads(raw_content)
            # Validate against Pydantic schema
            validated = ApparelMetadata(**parsed_json)
            
            return {
                "success": True,
                "raw": parsed_json,
                "validated": validated.model_dump(),
                "provider": "NVIDIA_Kimi",
                "model": self.model,
                "prompt_version": prompt_version
            }
            
        except (json.JSONDecodeError, ValidationError) as e:
            logging.error(f"Validation failed: {str(e)}")
            return {
                "success": False,
                "raw": raw_content if 'raw_content' in locals() else None,
                "error": str(e),
                "provider": "NVIDIA_Kimi",
                "model": self.model,
                "prompt_version": prompt_version
            }
        except Exception as e:
            logging.error(f"API Error: {str(e)}")
            return {
                "success": False,
                "error": str(e),
                "provider": "NVIDIA_Kimi",
                "model": self.model,
                "prompt_version": prompt_version
            }
