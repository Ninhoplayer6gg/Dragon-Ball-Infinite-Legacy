#!/usr/bin/env python3
"""End-to-end test with a real server and two real (headless) clients.

1. API phase: tests/mods/dbil_testtools/scenarios/integration.lua checks every
   system with the two connected players and logs PASS/FAIL lines.
2. Input phase: real key presses / mouse clicks are sent to P1's client with
   xdotool (charge Ki, double jump to fly, attacks, technique, guard, dash,
   character sheet) and the resulting server events are verified.
3. Persistence: P1 quits and rejoins; then the whole server restarts and both
   players rejoin. Character data must be identical.

Usage: python3 tests/run_integration.py [output_dir]
Exit code 0 only when everything passed and the server logged no errors.
"""
import os
import re
import sys
import time

from harness import Harness

OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/dbil_integration"
os.makedirs(OUT, exist_ok=True)

P1_DISPLAY, P2_DISPLAY = ":99", ":98"
failures = []


def expect(cond, name, detail=""):
    print(("PASS " if cond else "FAIL ") + name + (" " + detail if detail else ""))
    if not cond:
        failures.append(name)


def last_y(h, since):
    ys = [float(m.group(1)) for m in re.finditer(r"POS P1 \S+ (\S+) ", h.log_text()[since:])]
    return ys[-1] if ys else None


h = Harness(port=30220)
h.make_world({"dbil_test.scenario": "integration"})
try:
    h.start_server()
    h.start_display(P1_DISPLAY)
    h.start_display(P2_DISPLAY)
    h.start_client("P1", P1_DISPLAY)
    h.start_client("P2", P2_DISPLAY)

    # --- API phase -----------------------------------------------------------
    expect(h.wait_log("PHASE api start", 90), "api_phase_started")
    expect(h.wait_log("PHASE api done", 180), "api_phase_finished")
    h.screenshot(os.path.join(OUT, "01_api_done_P1.png"), P1_DISPLAY)
    h.screenshot(os.path.join(OUT, "02_api_done_P2.png"), P2_DISPLAY)

    # --- Input phase (real keys on P1) ----------------------------------------
    expect(h.wait_log("PHASE input", 30), "input_phase_started")
    time.sleep(1.5)
    d = P1_DISPLAY
    h.focus(d)
    h.tap("1", display=d)
    time.sleep(0.5)

    m = h.mark()
    h.key_down("e", d)
    time.sleep(1.2)
    h.screenshot(os.path.join(OUT, "03_charging.png"), d)
    time.sleep(1.0)
    h.key_up("e", d)
    expect(h.wait_new("EVENT charge_started P1", m, 5), "input_aux1_charges_ki")
    expect(h.wait_new("EVENT charge_stopped P1", m, 5), "input_charge_stops")

    time.sleep(0.8)
    m = h.mark()
    h.tap("space", 0.15, d)
    time.sleep(0.3)
    h.tap("space", 0.15, d)
    expect(h.wait_new("EVENT flight_started P1", m, 5), "input_double_jump_flies")
    time.sleep(0.6)
    y0 = last_y(h, m)
    h.key_down("space", d)
    time.sleep(1.5)
    h.key_up("space", d)
    time.sleep(1.2)
    y1 = last_y(h, m)
    expect(y0 is not None and y1 is not None and y1 > y0 + 3, "input_jump_ascends_in_flight", f"{y0} -> {y1}")
    h.key_down("w", d)
    time.sleep(1.0)
    h.screenshot(os.path.join(OUT, "04_flying.png"), d)
    h.key_up("w", d)

    m = h.mark()
    h.tap("2", display=d)
    time.sleep(0.4)
    h.click(1, display=d)
    expect(h.wait_new("ACTION P1 toggle_flight true", m, 5), "input_flight_item_toggles")
    expect(h.wait_new("EVENT flight_stopped P1 manual", m, 5), "input_flight_stops")
    time.sleep(3.0)

    m = h.mark()
    h.tap("1", display=d)
    time.sleep(0.4)
    h.click(1, display=d)
    expect(h.wait_new("ACTION P1 light_attack", m, 5), "input_click_light_attack")
    time.sleep(0.6)
    m = h.mark()
    h.click(3, display=d)
    expect(h.wait_new("ACTION P1 heavy_attack", m, 5), "input_rightclick_heavy_attack")

    time.sleep(1.0)
    m = h.mark()
    h.tap("3", display=d)
    time.sleep(0.4)
    h.click(1, display=d)
    expect(h.wait_new("EVENT technique_used P1 ki_blast", m, 5), "input_click_fires_technique")
    time.sleep(0.15)
    h.screenshot(os.path.join(OUT, "05_ki_blast.png"), d)

    # Chargeable technique: hold the button to power it up.
    time.sleep(5.5)
    m = h.mark()
    h.tap("4", display=d)
    time.sleep(0.4)
    h.xdo("mousedown", "1", display=d)
    time.sleep(2.4)
    h.screenshot(os.path.join(OUT, "05b_charging_wave.png"), d)
    h.xdo("mouseup", "1", display=d)
    ok = h.wait_new("EVENT technique_used P1 energy_wave", m, 6)
    charge = re.findall(r"technique_used P1 energy_wave charge=(\S+)", h.log_text()[m:])
    expect(ok and charge and float(charge[-1]) > 1.5, "input_hold_charges_energy_wave", str(charge))
    time.sleep(0.3)
    h.screenshot(os.path.join(OUT, "05c_energy_wave.png"), d)

    time.sleep(0.8)
    m = h.mark()
    h.key_down("z", d)
    time.sleep(1.0)
    h.key_up("z", d)
    expect(h.wait_new("EVENT guard_started P1", m, 5), "input_zoom_guards")

    time.sleep(0.5)
    m = h.mark()
    h.key_down("w", d)
    time.sleep(0.3)
    h.tap("e", 0.3, d)
    time.sleep(0.3)
    h.key_up("w", d)
    expect(h.wait_new("EVENT dash P1", m, 5), "input_aux1_move_dashes")

    time.sleep(1.0)
    h.tap("i", display=d)
    time.sleep(1.5)
    h.screenshot(os.path.join(OUT, "06_sheet.png"), d)
    h.tap("Escape", display=d)
    time.sleep(0.8)

    # --- Persistence: P1 quits and rejoins ---------------------------------
    m = h.mark()
    for p in h.procs:
        if "client_P1" in " ".join(getattr(p, "args", [])):
            p.terminate()
    expect(h.wait_new("P1 leaves game", m, 20), "p1_quit")
    time.sleep(1.0)
    m = h.mark()
    h.start_client("P1", P1_DISPLAY)
    expect(h.wait_new("PHASE persist_checked P1", m, 60), "p1_rejoined_and_checked")

    # --- Persistence: full server restart ----------------------------------
    m = h.mark()
    h.stop_server()
    expect("SHUTDOWN results" in h.log_text()[m:], "server_shutdown_clean")
    for p in list(h.procs):
        if "luanti" in os.path.basename(p.args[0]) and "server" not in p.args[0] and p.poll() is None:
            p.terminate()
    time.sleep(2.0)
    m = h.mark()
    h.start_server()
    h.start_client("P1", P1_DISPLAY)
    h.start_client("P2", P2_DISPLAY)
    ok1 = h.wait_new("PHASE persist_checked P1", m, 90)
    ok2 = h.wait_new("PHASE persist_checked P2", m, 90)
    expect(ok1 and ok2, "both_rejoined_after_restart")
    time.sleep(2.0)
    h.screenshot(os.path.join(OUT, "07_after_restart_P1.png"), P1_DISPLAY)
finally:
    log = h.log_text()
    h.close()

passes = log.count("[dbil-test] PASS")
fails = [l for l in log.splitlines() if "[dbil-test] FAIL" in l]
# The corrupted-save check logs these on purpose.
EXPECTED = ("account Ghost",)
errors = [l for l in log.splitlines() if "ERROR" in l and not any(e in l for e in EXPECTED)]
print(f"\nscenario checks: {passes} passed, {len(fails)} failed")
for line in fails:
    print("  ", line.split("[dbil-test] ")[1])
print(f"harness checks failed: {failures}")
print(f"server errors: {len(errors)}")
for line in errors[:20]:
    print("  ", line)
print("logs/screenshots:", h.dir, OUT)
sys.exit(0 if not fails and not failures and not errors else 1)
