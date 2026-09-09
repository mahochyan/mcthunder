"""Original deterministic game sounds; no recordings or external assets."""
import hashlib
import json
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio"
RATE = 22050
SOUNDS = {"engine": (2, True), "tracks": (2, True), "turret": (2, True),
          "fire": (2, True), "shot": (1.15, False), "flyby": (.6, False),
          "reload": (.32, False), "non_penetration": (.5, False),
          "ricochet": (.65, False), "penetrated": (.42, False),
          "explosion": (1.8, False), "destroyed": (.7, False), "world": (.38, False)}

def sample(kind, t, length, rng):
    noise = rng.uniform(-1, 1)
    sine = lambda hz: math.sin(math.tau * hz * t)
    if kind == "engine":
        return .5*sine(44)+.2*sine(88)+.12*sine(132)+noise*.08
    if kind == "tracks":
        return noise*(.15+.6*max(0, sine(18))**6)+.1*sine(90)
    if kind == "turret":
        return .4*sine(160)+.16*sine(320)+noise*.07
    if kind == "fire":
        return noise*(.35+.1*sine(3))+.1*sine(70)
    if kind in ("shot", "explosion"):
        return (noise*.65+.35*math.sin(math.tau*(90*t-22*t*t)))*math.exp(-t*(6 if kind=="shot" else 3))
    if kind == "ricochet":
        return (.6*math.sin(math.tau*(1800*t-850*t*t))+noise*.18)*math.exp(-t*7)
    if kind == "non_penetration":
        return (sine(310)*.45+sine(503)*.2+noise*.25)*math.exp(-t*10)
    if kind == "penetrated":
        return (noise*.8+sine(870)*.15)*math.exp(-t*15)
    if kind == "reload":
        return (noise*.65+sine(620)*.15)*sum(math.exp(-max(0,t-p)*80) if t>=p else 0 for p in (0,.14,.24))
    if kind == "flyby":
        return (noise*.2+math.sin(math.tau*(900*t-400*t*t))*.3)*math.sin(math.pi*t/length)**2
    if kind == "destroyed":
        return (sine(180)*.4+sine(135)*.3)*math.exp(-t*5)
    return (noise*.8+sine(100)*.15)*math.exp(-t*16)

OUT.mkdir(parents=True, exist_ok=True)
manifest = {"version": 1, "source": "Original mathematical synthesis by this project; no recorded samples", "redistribute_source_allowed": True,
            "generator": "authoring/build_audio.py", "sample_rate": RATE, "clips": {}}
for index, (name, (seconds, loop)) in enumerate(SOUNDS.items()):
    rng = random.Random(26000+index)
    values = [sample(name, i/RATE, seconds, rng) for i in range(round(seconds*RATE))]
    # Fade both boundaries, also making looping assets seam-safe.
    values = [v*min(1, i/110, (len(values)-1-i)/220) for i,v in enumerate(values)]
    peak = max(abs(v) for v in values)
    pcm = b"".join(struct.pack('<h', round(v/peak*.8*32767)) for v in values)
    path = OUT / (name+'.wav')
    with wave.open(str(path), 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(RATE); wav.writeframes(pcm)
    manifest["clips"][name] = {"path": "res://assets/audio/"+path.name, "loop": loop, "seconds": seconds,
                               "peak_linear": .8, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
(OUT/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
print('Generated', len(SOUNDS), 'original PCM clips')
