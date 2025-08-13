import json
import os
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .conftest import BASE_URL

CACHE_PATH = Path(__file__).resolve().parent / ".model_cache.json"


def _load_cache() -> Dict[str, Any]:
	if CACHE_PATH.exists():
		try:
			return json.loads(CACHE_PATH.read_text())
		except Exception:
			return {}
	return {}


def _save_cache(data: Dict[str, Any]) -> None:
	try:
		CACHE_PATH.write_text(json.dumps(data, indent=2))
	except Exception:
		pass


def _get_max_ram_gb(session) -> float:
	"""Return max RAM GB allowed for tests, honoring MLX_MAX_RAM_GB env override."""
	override = os.environ.get("MLX_MAX_RAM_GB")
	if override:
		try:
			return float(override)
		except ValueError:
			pass
	# Try server status
	try:
		r = session.get(f"{BASE_URL}/v1/system/status", timeout=5)
		if r.status_code == 200:
			mem = r.json().get("system", {}).get("memory", {})
			total = mem.get("total_gb")
			if total:
				return float(total) * 0.8
	except Exception:
		pass
	# Fallback conservative default
	return 8.0


def _list_installed(session) -> List[str]:
	r = session.get(f"{BASE_URL}/v1/models", timeout=10)
	if r.status_code != 200:
		return []
	return [m["id"] for m in r.json().get("data", [])]


def _ensure_install_and_ready(session, model_name: str, model_id: Optional[str] = None, timeout_s: int = 240) -> bool:
	# Ensure installed
	r = session.get(f"{BASE_URL}/v1/models/{model_name}", timeout=10)
	if r.status_code != 200:
		if not model_id:
			return False
		payload = {"model_id": model_id, "name": model_name}
		session.post(f"{BASE_URL}/v1/models/install", json=payload, timeout=180)
	# Load and wait
	try:
		session.post(f"{BASE_URL}/v1/models/{model_name}/load", timeout=10)
	except Exception:
		pass
	deadline = time.time() + timeout_s
	while time.time() < deadline:
		try:
			h = session.get(f"{BASE_URL}/v1/models/{model_name}/health", timeout=5)
			if h.status_code == 200 and h.json().get("healthy"):
				return True
		except Exception:
			pass
		time.sleep(2)
	return False


CANDIDATES: Dict[str, List[Tuple[str, str]]] = {
	"text": [
		("smollm3-3b-4bit", "mlx-community/SmolLM3-3B-4bit"),
		("llama-3.2-3b-instruct-4bit", "mlx-community/Llama-3.2-3B-Instruct-4bit"),
	],
	"embedding": [
		("bge-small-en-v1-5-bf16", "bge-small-en-v1-5-bf16"),
		("all-minilm-l6-v2-4bit", "mlx-community/all-MiniLM-L6-v2-4bit"),
		("qwen3-embedding-0-6b-4bit-dwq", "mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ"),
	],
	"audio": [
		("whisper-tiny", "mlx-community/whisper-tiny"),
		("parakeet-tdt-0-6b-v2", "mlx-community/parakeet-tdt-0.6b-v2"),
	],
}


def pick_or_install_model(session, category: str) -> Optional[str]:
	"""Pick a model name for category, preferring installed, else compatible, with caching."""
	cache = _load_cache()
	installed = set(_list_installed(session))
	# 1. Env override
	override = os.environ.get(f"MLX_TEST_{category.upper()}")
	if override:
		if _ensure_install_and_ready(session, override):
			return override
	# 2. Prefer installed candidates
	for name, _mid in CANDIDATES.get(category, []):
		if name in installed:
			if _ensure_install_and_ready(session, name):
				cache.setdefault("last_used", {})[category] = name
				_save_cache(cache)
				return name
	# 3. Use cached last choice
	last = cache.get("last_used", {}).get(category)
	if last and _ensure_install_and_ready(session, last):
		return last
	# 4. Discover compatible from server within RAM budget
	max_ram = _get_max_ram_gb(session)
	try:
		r = session.get(f"{BASE_URL}/v1/discover/compatible", params={"max_memory_gb": max_ram}, timeout=20)
		if r.status_code == 200:
			models = r.json().get("models", [])
			# Filter by category if server provides model_type
			filtered = [m for m in models if m.get("model_type", "").lower() == category]
			# Try candidates first among compatible list
			ids = [m.get("id") for m in filtered if m.get("id")]
			for name, mid in CANDIDATES.get(category, []):
				if mid in ids:
					chosen_name = name
					if _ensure_install_and_ready(session, chosen_name, mid):
						cache.setdefault("last_used", {})[category] = chosen_name
						_save_cache(cache)
						return chosen_name
			# Else pick first compatible
			if filtered:
				mid = filtered[0]["id"]
				name = mid.split("/")[-1]
				if _ensure_install_and_ready(session, name, mid):
					cache.setdefault("last_used", {})[category] = name
					_save_cache(cache)
					return name
	except Exception:
		pass
	# 5. Fallback to first installed
	if installed:
		name = list(installed)[0]
		if _ensure_install_and_ready(session, name):
			cache.setdefault("last_used", {})[category] = name
			_save_cache(cache)
			return name
	return None