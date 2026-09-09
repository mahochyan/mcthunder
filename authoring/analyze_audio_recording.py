"""Independent PCM analysis of an actual saved Godot bus recording."""
import array
import hashlib
import json
import math
import sys
import wave
from pathlib import Path

path = Path(sys.argv[1])
with wave.open(str(path), "rb") as wav:
    assert wav.getsampwidth() == 2, "Expected captured 16-bit PCM"
    values = array.array("h", wav.readframes(wav.getnframes()))
    if sys.byteorder != "little": values.byteswap()
    peak = max(abs(x) for x in values) / 32768
    rms = math.sqrt(sum((x/32768)**2 for x in values)/len(values))
    report = {"file": path.name, "channels": wav.getnchannels(), "rate": wav.getframerate(),
              "seconds": wav.getnframes()/wav.getframerate(), "peak_linear": peak,
              "peak_dbfs": 20*math.log10(max(peak, 1e-10)), "rms_dbfs": 20*math.log10(max(rms, 1e-10)),
              "clipped_samples": sum(abs(x)>=32767 for x in values),
              "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "listening": "NOT_RUN"}
report["passed"] = peak > .00001 and report["clipped_samples"] == 0
path.with_suffix(".analysis.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps(report))
sys.exit(0 if report["passed"] else 1)
