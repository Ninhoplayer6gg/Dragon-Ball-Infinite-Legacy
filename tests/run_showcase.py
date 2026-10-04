#!/usr/bin/env python3
"""Third-person visual QA: charging aura, Ki blast, flight, character sheet.
Usage: python3 tests/run_showcase.py <out_dir> [race]"""
import os
import sys
import time

from harness import Harness

out = sys.argv[1]
race = sys.argv[2] if len(sys.argv) > 2 else "saiyan"
touch = len(sys.argv) > 3 and sys.argv[3] == "touch"
os.makedirs(out, exist_ok=True)
h = Harness(port=30230)
h.make_world({"dbil_test.scenario": "showcase", "dbil_test.race": race})
d = ":99"
try:
    h.start_server()
    if touch:
        # Phone-like screen with the touchscreen GUI enabled.
        h.start_display(d, "1600x720x24")
        h.start_client("P1", d, {"touch_controls": "true", "screen_w": "1600", "screen_h": "720",
                                 "display_density_factor": "1.4"})
    else:
        h.start_display(d)
        h.start_client("P1", d)
    h.wait_log("scene ready", 90)
    time.sleep(4)
    h.focus(d)
    h.screenshot(os.path.join(out, "a_idle.png"), d)
    h.key_down("e", d)
    time.sleep(1.5)
    h.screenshot(os.path.join(out, "b_charging.png"), d)
    time.sleep(1.5)
    h.key_up("e", d)
    time.sleep(0.5)
    h.tap("3", display=d)
    time.sleep(0.3)
    h.click(1, display=d)
    time.sleep(0.2)
    h.screenshot(os.path.join(out, "c_ki_blast.png"), d)
    time.sleep(0.6)
    h.screenshot(os.path.join(out, "d_impact.png"), d)
    time.sleep(1.0)
    h.tap("1", display=d)
    h.tap("space", 0.15, d)
    time.sleep(0.3)
    h.tap("space", 0.15, d)
    time.sleep(0.3)
    h.key_down("space", d)
    time.sleep(0.8)
    h.key_up("space", d)
    h.key_down("w", d)
    time.sleep(1.2)
    h.screenshot(os.path.join(out, "e_flying.png"), d)
    h.key_up("w", d)
    time.sleep(1.0)
    h.screenshot(os.path.join(out, "f_hover.png"), d)
    h.tap("i", display=d)
    time.sleep(1.5)
    h.screenshot(os.path.join(out, "g_sheet.png"), d)
    print("\n".join(h.errors()[:20]))
finally:
    h.close()
    print("workdir:", h.dir)
