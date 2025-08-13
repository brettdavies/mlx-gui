from dataclasses import dataclass
from types import SimpleNamespace
from typing import Any, Dict, List, Optional, AsyncIterator

from mlx_gui.mlx_integration import GenerationConfig, GenerationResult


class StubWrapper:
    def __init__(self, kind: str = "text"):
        self.model_type = kind
        self.tokenizer = SimpleNamespace(encode=lambda s: list(str(s).encode("utf-8")))

    def transcribe_audio(
        self,
        file_path: str,
        language: Optional[str] = None,
        initial_prompt: Optional[str] = None,
        temperature: float = 0.0,
    ) -> Dict[str, str]:
        return {"text": "transcribed"}

    def generate_embeddings(self, texts: List[str]) -> List[List[float]]:
        dim = 16
        return [[(i + 1) * 0.01 for i in range(dim)] for _ in texts]

    def generate_with_images(
        self, messages: List[Dict[str, Any]], image_file_paths: List[str], config: GenerationConfig
    ) -> Any:
        return SimpleNamespace(text="red", tokens_generated=3, generation_time_ms=10)


class StubModelManager:
    def __init__(self):
        self._loaded: Dict[str, Any] = {}

    async def load_model_async(self, model_name: str, model_path: str, priority: int = 0) -> bool:
        kind = "text"
        l = model_name.lower()
        if "embed" in l:
            kind = "embedding"
        elif any(k in l for k in ["whisper", "parakeet", "audio"]):
            kind = "audio"
        elif any(k in l for k in ["gemma", "vlm", "vision", "3n", "qwen2-vl"]):
            kind = "vision"
        self._loaded[model_name] = SimpleNamespace(mlx_wrapper=StubWrapper(kind=kind))
        return True

    def get_model_for_inference(self, model_name: str) -> Optional[Any]:
        return self._loaded.get(model_name)

    def unload_model(self, model_name: str) -> bool:
        return self._loaded.pop(model_name, None) is not None

    async def generate_text(self, model_name: str, prompt: str, config: GenerationConfig) -> GenerationResult:
        text = "4" if "2+2" in prompt else "ok"
        return GenerationResult(
            text=text,
            prompt=prompt,
            total_tokens=2,
            prompt_tokens=1,
            completion_tokens=1,
            generation_time_seconds=0.01,
            tokens_per_second=100.0,
        )

    async def generate_text_stream(
        self, model_name: str, prompt: str, config: GenerationConfig
    ) -> AsyncIterator[str]:
        for chunk in ["he", "ll", "o"]:
            yield chunk