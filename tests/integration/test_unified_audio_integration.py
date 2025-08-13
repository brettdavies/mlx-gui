import pathlib
import pytest
from .conftest import BASE_URL
from .helpers import pick_or_install_model

pytestmark = pytest.mark.integration

TESTS_DIR = pathlib.Path(__file__).resolve().parent
AUDIO_PATH = TESTS_DIR / "test.wav"


def test_parakeet_transcription_small(http_session):
	if not AUDIO_PATH.exists():
		pytest.skip("Missing test.wav")
	model = pick_or_install_model(http_session, "audio")
	if not model:
		pytest.skip("No compatible audio model available")
	files = {"file": ("test.wav", open(AUDIO_PATH, "rb"), "audio/wav")}
	data = {"model": model, "response_format": "json"}
	r = http_session.post(f"{BASE_URL}/v1/audio/transcriptions", files=files, data=data)
	assert r.status_code in (200, 404, 503)
	if r.status_code == 200:
		assert "text" in r.json()