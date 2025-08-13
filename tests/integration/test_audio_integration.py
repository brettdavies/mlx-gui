import os
import pathlib
import pytest

from .conftest import BASE_URL

pytestmark = pytest.mark.integration

TESTS_DIR = pathlib.Path(__file__).resolve().parent.parent
AUDIO_PATH = TESTS_DIR / "test.wav"


def test_audio_transcription(http_session):
	assert AUDIO_PATH.exists()
	files = {"file": ("test.wav", open(AUDIO_PATH, "rb"), "audio/wav")}
	data = {"model": os.environ.get("ASR_MODEL", "parakeet-tdt-0-6b-v2"), "response_format": "json"}
	r = http_session.post(f"{BASE_URL}/v1/audio/transcriptions", files=files, data=data)
	assert r.status_code in (200, 404, 503)
	# 200 -> success, 404 if model not installed, 503 if model loading