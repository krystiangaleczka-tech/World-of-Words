"""Generate original deterministic P1 WAV recordings, dedicated to CC0-1.0."""

import io
import math
import struct
import wave
from pathlib import Path

RATE = 22050
TONES = {
    "tile_touch": (660, 0.045),
    "word_valid": (880, 0.14),
    "word_bonus": (1047, 0.16),
    "word_already": (440, 0.08),
    "word_invalid": (220, 0.10),
    "level_complete": (1320, 0.22),
}


def recording(frequency: int, duration: float) -> bytes:
    frames = int(RATE * duration)
    samples = bytearray()
    for index in range(frames):
        envelope = math.sin(math.pi * index / (frames - 1)) ** 2
        tone = math.sin(2 * math.pi * frequency * index / RATE)
        samples.extend(struct.pack("<h", round(12000 * envelope * tone)))
    output = io.BytesIO()
    with wave.open(output, "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(samples)
    return output.getvalue()


def generate(directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for cue, (frequency, duration) in TONES.items():
        (directory / f"{cue}.wav").write_bytes(recording(frequency, duration))


if __name__ == "__main__":
    generate(Path(__file__).resolve().parents[1] / "game/assets/audio/p1")
