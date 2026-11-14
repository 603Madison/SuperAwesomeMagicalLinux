#!/usr/bin/env python3
"""A stand-in for Hyprland's IPC, for screenshotting the shell under headless sway (run.sh).

Answers the shell's requests on $XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock
with one focused monitor (named like sway's output) and one workspace, keeps .socket2.sock (the
event stream) open, and logs every request to /out/hypr-requests.log.

    python3 fake_hypr.py emit 'samsnap>>10,60,940,1010'

sends an event to the shell (a SHOTS "!" command can), as if Hyprland had.
"""
import json
import os
import socket
import sys
import threading

MON = os.environ.get("FAKE_MONITOR", "HEADLESS-1")
WS = {"id": 1, "name": "1", "monitor": MON, "monitorID": 0, "windows": 0,
      "hasfullscreen": False, "lastwindow": "0x0", "lastwindowtitle": "", "ispersistent": False}
MONITOR = {"id": 0, "name": MON, "description": "Headless Display 0001", "make": "Headless", "model": "Display", "serial": "0001",
           "width": 1920, "height": 1080, "physicalWidth": 0, "physicalHeight": 0,
           "refreshRate": 60.0, "x": 0, "y": 0, "activeWorkspace": {"id": 1, "name": "1"},
           "specialWorkspace": {"id": 0, "name": ""}, "reserved": [0, 0, 0, 0], "scale": 1.0,
           "transform": 0, "focused": True, "dpmsStatus": True, "vrr": False, "solitary": "0",
           "activelyTearing": False, "directScanoutTo": "0", "disabled": False,
           "currentFormat": "XRGB8888", "mirrorOf": "none",
           "availableModes": ["1920x1080@120.00Hz", "1920x1080@60.00Hz", "1680x1050@60.00Hz", "1280x800@60.00Hz"]}

def client(n, cls, title, ws_id, ws_name, x, y):
    return {"address": f"0x{n:012x}", "mapped": True, "hidden": False, "at": [x, y], "size": [900, 600],
            "workspace": {"id": ws_id, "name": ws_name}, "floating": True, "pseudo": False, "monitor": 0,
            "class": cls, "title": title, "initialClass": cls, "initialTitle": title, "pid": 1000 + n,
            "xwayland": False, "pinned": False, "fullscreen": 0, "fullscreenClient": 0, "grouped": [],
            "tags": [], "swallowing": "0x0", "focusHistoryID": n, "inhibitingIdle": False}


# FAKE_WINDOWS=1: a few open windows (one minimized), for screenshots of the taskbar.
CLIENTS = [
    client(1, "io.github._603madison.SuperAwesomeMagicalBrowser", "SuperAwesomeMagical Browser", 1, "1", 300, 120),
    client(2, "foot", "Terminal", 1, "1", 520, 380),
    client(3, "org.gnome.Nautilus", "Home", 1, "1", 700, 200),
    client(4, "io.github._603madison.SuperAwesomeMagicalMusic", "SuperAwesomeMagicalMusic", -98, "special:minimized", 400, 300),
] if os.environ.get("FAKE_WINDOWS") else []
MINIMIZED_WS = {"id": -98, "name": "special:minimized", "monitor": MON, "monitorID": 0, "windows": 1,
                "hasfullscreen": False, "lastwindow": CLIENTS[-1]["address"] if CLIENTS else "0x0",
                "lastwindowtitle": "", "ispersistent": False}
if CLIENTS:
    WS.update({"windows": 3, "lastwindow": CLIENTS[0]["address"], "lastwindowtitle": CLIENTS[0]["title"]})

ANSWERS = {
    "monitors": [MONITOR],
    "workspaces": [WS] + ([MINIMIZED_WS] if CLIENTS else []),
    "activeworkspace": WS,
    "clients": CLIENTS,
    "activewindow": CLIENTS[0] if CLIENTS else {},
    "layers": {},
    "devices": {"mice": [], "tablets": [], "touch": [], "switches": [], "keyboards": [
        {"address": "0x1", "name": "keyboard", "rules": "", "model": "", "layout": "us",
         "variant": "", "options": "", "active_keymap": "English (US)", "capsLock": False,
         "numLock": False, "main": True}]},
    "version": {"branch": "", "commit": "", "version": "0.57.2", "dirty": False, "tag": "v0.57.2"},
    "status": {"configProvider": "lua"},
}

base = os.path.join(os.environ["XDG_RUNTIME_DIR"], "hypr", os.environ["HYPRLAND_INSTANCE_SIGNATURE"])

if sys.argv[1:2] == ["emit"]:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as c:
        c.connect(os.path.join(base, ".socket.sock"))
        c.sendall(("fake-event " + sys.argv[2]).encode())
        c.recv(16)
    sys.exit()

os.makedirs(base, exist_ok=True)
events = []  # the shell's connections to the event stream
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
    if word == "fake-event":
        for c in list(events):
            try:
                c.sendall((cmd.split(" ", 1)[1] + "\n").encode())
            except OSError:
                events.remove(c)
        return b"ok"
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
    while True:
        c, _ = s.accept()
        events.append(c)  # kept open; "emit" sends events down it


threading.Thread(target=serve_events, daemon=True).start()
serve_requests()
