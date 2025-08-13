import io
import wave


def make_wav_bytes(duration_s: float = 0.05, framerate: int = 16000) -> bytes:
    num_frames = int(duration_s * framerate)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(framerate)
        wf.writeframes(b"\x00\x00" * num_frames)
    return buf.getvalue()