#!/usr/bin/env python3
"""Visual scene runner: starts server + one headless client and takes screenshots.

Usage: python3 tests/run_visual.py <scenario> <out_dir> [key=value settings...]
"""
import os
import sys
import time

from harness import Harness

scenario, outdir = sys.argv[1], sys.argv[2]
extra = dict(a.split("=", 1) for a in sys.argv[3:])
os.makedirs(outdir, exist_ok=True)
h = Harness(port=int(extra.pop("port", "30210")))
settings = {"dbil_test.scenario": scenario}
settings.update(extra)
h.make_world(settings)
try:
    h.start_server()
    h.start_display()
    h.start_client("P1")
    ok = h.wait_log("scene ready", 60) or h.wait_log("P1 joins game", 5)
    time.sleep(float(extra.get("wait", "6")))
    for i in range(int(extra.get("shots", "1"))):
        h.screenshot(os.path.join(outdir, f"{scenario}_{i}.png"))
        time.sleep(1.0)
    print("scene ready:", ok)
    print("\n".join(h.errors()[:30]))
finally:
    h.close()
    print("workdir:", h.dir)
