#!/usr/bin/env python3
"""Hold-Super -> Quickshell cheatsheet overlay.

niri (like most Wayland compositors) can't bind on key *release* or on a modifier
*hold*, so this tiny watcher reads the keyboard directly and drives the overlay
over Quickshell IPC:

  - Super (Left/Right Meta) held alone past HOLD_MS  -> `qs ipc call cheatsheet open`
  - Super released, or any other key pressed while held -> `... close`

Devices are read but never grabbed (no EVIOCGRAB), so every event still reaches
the compositor — Super keeps working as a normal modifier for all Super+X binds.

argv[1] is the `qs` binary path (the systemd/niri spawn passes an absolute path so
it doesn't depend on PATH). Needs read access to /dev/input/event* (input group).
"""
import selectors
import subprocess
import sys
import time

import evdev
from evdev import ecodes

HOLD_MS = 200
META_KEYS = {ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA}
QS = sys.argv[1] if len(sys.argv) > 1 else "qs"


def ipc(action):
    try:
        subprocess.Popen([QS, "ipc", "call", "cheatsheet", action],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def keyboards():
    devs = []
    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
        except Exception:
            continue
        caps = d.capabilities().get(ecodes.EV_KEY, [])
        if ecodes.KEY_LEFTMETA in caps:
            devs.append(d)
    return devs


def run():
    sel = selectors.DefaultSelector()
    for d in keyboards():
        sel.register(d, selectors.EVENT_READ)
    if not sel.get_map():
        # No keyboards found yet — back off and let the supervisor restart us.
        time.sleep(5)
        return

    meta_down = False
    shown = False
    suppressed = False  # a non-Meta key was pressed during this hold
    deadline = None     # monotonic time at which to open

    while True:
        timeout = None if deadline is None else max(0.0, deadline - time.monotonic())
        events = sel.select(timeout)

        # Open once the hold threshold passes (Super still down, nothing else hit).
        if deadline is not None and time.monotonic() >= deadline:
            deadline = None
            if meta_down and not suppressed and not shown:
                ipc("open")
                shown = True

        for key, _ in events:
            dev = key.fileobj
            try:
                for ev in dev.read():
                    if ev.type != ecodes.EV_KEY:
                        continue
                    code, val = ev.code, ev.value
                    if code in META_KEYS:
                        if val == 1:            # Meta pressed
                            meta_down = True
                            suppressed = False
                            shown = False
                            deadline = time.monotonic() + HOLD_MS / 1000.0
                        elif val == 0:          # Meta released
                            meta_down = False
                            deadline = None
                            if shown:
                                ipc("close")
                            shown = False
                            suppressed = False
                    elif val == 1 and meta_down:  # another key during the hold
                        suppressed = True
                        deadline = None
                        if shown:
                            ipc("close")
                            shown = False
            except OSError:
                # Device went away (unplug/suspend) — restart to re-enumerate.
                return


def main():
    while True:
        try:
            run()
        except Exception:
            time.sleep(5)


if __name__ == "__main__":
    main()
