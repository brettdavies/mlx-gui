import io
import pytest
from tests.unit.utils import make_wav_bytes


@pytest.mark.asyncio
async def test_audio_transcription_ok(client, seed_models):
    wav_bytes = make_wav_bytes()
    files = {"file": ("sample.wav", io.BytesIO(wav_bytes), "audio/wav")}
    data = {"model": "stub-audio", "response_format": "json"}
    r = await client.post("/v1/audio/transcriptions", files=files, data=data)
    assert r.status_code == 200
    assert r.json()["text"] == "transcribed"