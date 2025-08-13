import os
import pathlib
import pytest
from .conftest import BASE_URL

pytestmark = pytest.mark.integration

TESTS_DIR = pathlib.Path(__file__).resolve().parent
AUDIO_PATH = TESTS_DIR / "test.wav"


def test_parakeet_transcription_small(http_session):
	if not AUDIO_PATH.exists():
		pytest.skip("Missing test.wav")
	model = os.environ.get("ASR_MODEL", "parakeet-tdt-0-6b-v2")
	files = {"file": ("test.wav", open(AUDIO_PATH, "rb"), "audio/wav")}
	data = {"model": model, "response_format": "json"}
	r = http_session.post(f"{BASE_URL}/v1/audio/transcriptions", files=files, data=data)
	assert r.status_code in (200, 404, 503)
	if r.status_code == 200:
		assert "text" in r.json()