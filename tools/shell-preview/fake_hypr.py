#!/usr/bin/env python3
"""A stand-in for Hyprland's IPC, for screenshotting the shell under headless sway (run.sh).

Answers the shell's requests on $XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock
with one focused monitor (named like sway's output) and one workspace, keeps .socket2.sock (the
event stream) open, and logs every request to /out/hypr-requests.log.
"""
import json
import os
import socket
import threading

MON = os.environ.get("FAKE_MONITOR", "HEADLESS-1")
WS = {"id": 1, "name": "1", "monitor": MON, "monitorID": 0, "windows": 0,
      "hasfullscreen": False, "lastwindow": "0x0", "lastwindowtitle": "", "ispersistent": False}
MONITOR = {"id": 0, "name": MON, "description": "Headless", "make": "", "model": "", "serial": "",
           "width": 1920, "height": 1080, "physicalWidth": 0, "physicalHeight": 0,
           "refreshRate": 60.0, "x": 0, "y": 0, "activeWorkspace": {"id": 1, "name": "1"},
           "specialWorkspace": {"id": 0, "name": ""}, "reserved": [0, 0, 0, 0], "scale": 1.0,
           "transform": 0, "focused": True, "dpmsStatus": True, "vrr": False, "solitary": "0",
           "activelyTearing": False, "directScanoutTo": "0", "disabled": False,
           "currentFormat": "XRGB8888", "mirrorOf": "none", "availableModes": ["1920x1080@60.00Hz"]}
ANSWERS = {
    "monitors": [MONITOR],
    "workspaces": [WS],
    "activeworkspace": WS,
    "clients": [],
    "activewindow": {},
    "layers": {},
    "devices": {"mice": [], "tablets": [], "touch": [], "switches": [], "keyboards": [
        {"address": "0x1", "name": "keyboard", "rules": "", "model": "", "layout": "us",
         "variant": "", "options": "", "active_keymap": "English (US)", "capsLock": False,
         "numLock": False, "main": True}]},
    "version": {"branch": "", "commit": "", "version": "0.57.2", "dirty": False, "tag": "v0.57.2"},
    "status": {"configProvider": "lua"},
}

base = os.path.join(os.environ["XDG_RUNTIME_DIR"], "hypr", os.environ["HYPRLAND_INSTANCE_SIGNATURE"])
os.makedirs(base, exist_ok=True)
log = open("/out/hypr-requests.log", "a", buffering=1)


def answer(req: str) -> bytes:
    log.write(req + "\n")
    cmd = req.strip()
    as_json = cmd.startswith("j/")
    if as_json:
        cmd = cmd[2:]
    word = cmd.split()[0] if cmd else ""
    if word in ANSWERS:
        return json.dumps(ANSWERS[word]).encode()
    if word == "getoption":
        return json.dumps({"option": cmd.split()[-1], "int": 0, "set": False}).encode()
    return b"ok"


def serve_requests():
    path = os.path.join(base, ".socket.sock")
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.bind(path)
    s.listen(16)
    while True:
        c, _ = s.accept()
        try:
            data = c.recv(65536).decode(errors="replace")
            c.sendall(answer(data))
        finally:
            c.close()


def serve_events():
    path = os.path.join(base, ".socket2.sock")
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.bind(path)
    s.listen(16)
    held = []
    while True:
        c, _ = s.accept()
        held.append(c)  # never send anything; just keep it open


threading.Thread(target=serve_events, daemon=True).start()
serve_requests()
