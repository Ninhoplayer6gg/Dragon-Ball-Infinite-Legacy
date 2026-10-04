#!/usr/bin/env python3
"""Test harness: real Luanti server + headless clients (Xvfb) + input/screenshots.

Used by tests/run_*.py scripts. Requires: Xvfb, xdotool, ImageMagick (import),
a Luanti build (set LUANTI_BIN to the folder with `luanti` and `luantiserver`).
"""
import os
import shutil
import signal
import subprocess
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
BIN = os.environ.get("LUANTI_BIN", "/home/user/luanti-org/luanti/bin")


class Harness:
    def __init__(self, workdir=None, port=30200):
        self.dir = workdir or tempfile.mkdtemp(prefix="dbil_test_")
        self.port = port
        self.procs = []
        self.world = os.path.join(self.dir, "world")
        self.server_log = os.path.join(self.dir, "server.log")

    # -- server -----------------------------------------------------------
    def make_world(self, settings=None, fresh=True):
        if fresh and os.path.exists(self.world):
            shutil.rmtree(self.world)
        os.makedirs(os.path.join(self.world, "worldmods"), exist_ok=True)
        dst = os.path.join(self.world, "worldmods", "dbil_testtools")
        if os.path.exists(dst):
            shutil.rmtree(dst)
        shutil.copytree(os.path.join(HERE, "mods", "dbil_testtools"), dst)
        conf = {
            "mg_name": "v7",
            "fixed_map_seed": "42",
            "enable_damage": "true",
            "creative_mode": "false",
            "server_announce": "false",
            "enable_ipv6": "false",
            "ipv6_server": "false",
            "port": str(self.port),
            "debug_log_level": "action",
            "disallow_empty_password": "false",
            "time_speed": "0",
            "world_start_time": "9000",
        }
        conf.update(settings or {})
        self.server_conf = os.path.join(self.dir, "server.conf")
        with open(self.server_conf, "w") as f:
            for k, v in conf.items():
                f.write(f"{k} = {v}\n")

    def start_server(self):
        cmd = [os.path.join(BIN, "luantiserver"), "--gameid", "dbil", "--world", self.world,
               "--config", self.server_conf, "--logfile", self.server_log]
        p = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.procs.append(p)
        self.server = p
        self.wait_log("listening on", 30)
        return p

    def stop_server(self):
        if self.server and self.server.poll() is None:
            self.server.send_signal(signal.SIGINT)
            try:
                self.server.wait(20)
            except subprocess.TimeoutExpired:
                self.server.kill()

    # -- clients ------------------------------------------------------------
    def start_display(self, display=":99", size="1280x720x24"):
        p = subprocess.Popen(["Xvfb", display, "-screen", "0", size, "-nolisten", "tcp"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.procs.append(p)
        time.sleep(1.0)
        return p

    def start_client(self, name, display=":99", extra_conf=None):
        conf_path = os.path.join(self.dir, f"client_{name}.conf")
        shutil.copy(os.path.join(HERE, "client.conf"), conf_path)
        if extra_conf:
            with open(conf_path, "a") as f:
                for k, v in extra_conf.items():
                    f.write(f"{k} = {v}\n")
        log = os.path.join(self.dir, f"client_{name}.log")
        env = dict(os.environ, DISPLAY=display, LIBGL_ALWAYS_SOFTWARE="1")
        cmd = [os.path.join(BIN, "luanti"), "--config", conf_path, "--address", "127.0.0.1",
               "--port", str(self.port), "--name", name, "--password", "", "--go",
               "--logfile", log]
        p = subprocess.Popen(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.procs.append(p)
        return p

    def screenshot(self, path, display=":99"):
        subprocess.run(["import", "-display", display, "-window", "root", path], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return path

    def xdo(self, *args, display=":99"):
        env = dict(os.environ, DISPLAY=display)
        subprocess.run(["xdotool", *args], env=env, check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def focus(self, display=":99"):
        """Points the mouse at the window and sends a harmless key: the first
        key event after the pointer enters the window is dropped by the client."""
        self.xdo("mousemove", "640", "360", display=display)
        time.sleep(0.3)
        self.tap("shift", 0.05, display)
        time.sleep(0.3)

    def key_down(self, key, display=":99"):
        self.xdo("keydown", key, display=display)

    def key_up(self, key, display=":99"):
        self.xdo("keyup", key, display=display)

    def tap(self, key, hold=0.15, display=":99"):
        self.key_down(key, display)
        time.sleep(hold)
        self.key_up(key, display)

    def click(self, button=1, hold=0.08, display=":99"):
        self.xdo("mousedown", str(button), display=display)
        time.sleep(hold)
        self.xdo("mouseup", str(button), display=display)

    # -- logs ---------------------------------------------------------------
    def log_text(self):
        try:
            with open(self.server_log, encoding="utf-8", errors="replace") as f:
                return f.read()
        except FileNotFoundError:
            return ""

    def wait_log(self, needle, timeout=30.0):
        end = time.time() + timeout
        while time.time() < end:
            if needle in self.log_text():
                return True
            time.sleep(0.25)
        return False

    def mark(self):
        """Position in the server log; use with wait_new to see only new lines."""
        return len(self.log_text())

    def wait_new(self, needle, since, timeout=10.0):
        end = time.time() + timeout
        while time.time() < end:
            if needle in self.log_text()[since:]:
                return True
            time.sleep(0.2)
        return False

    def lines_since(self, since, prefix):
        return [l for l in self.log_text()[since:].splitlines() if prefix in l]

    def errors(self):
        return [line for line in self.log_text().splitlines()
                if "ERROR" in line or "stack traceback" in line]

    def close(self):
        for p in reversed(self.procs):
            if p.poll() is None:
                p.send_signal(signal.SIGINT)
        time.sleep(1.0)
        for p in reversed(self.procs):
            if p.poll() is None:
                p.kill()
        self.procs = []
