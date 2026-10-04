#!/usr/bin/env python3
"""Screenshots of every character sheet tab. Usage: python3 tests/run_sheet.py <out_dir>"""
import os
import sys
import time

from harness import Harness

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
h = Harness(port=30240)
h.make_world({"dbil_test.scenario": "showcase", "dbil_test.third_person": "false",
              "dbil_test.cycle_tabs": "true", "dbil_test.race": "human"})
d = ":99"
try:
    h.start_server()
    h.start_display(d)
    h.start_client("P1", d)
    h.wait_log("scene ready", 90)
    time.sleep(3)
    h.focus(d)
    h.tap("i", display=d)
    for tab in range(1, 7):
        m = h.mark()
        h.wait_new(f"sheet tab {tab}", m, 20)
        time.sleep(1.2)
        h.screenshot(os.path.join(out, f"tab{tab}.png"), d)
    print("\n".join(h.errors()[:20]))
finally:
    h.close()
