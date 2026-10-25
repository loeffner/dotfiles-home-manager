# Quickshell shell

terra's desktop shell: a top bar whose popouts grow out of it ("islands"),
notification toasts, a hold-Super keybind cheatsheet and a few OSDs. Gruvbox
on a small Material-3 token vocabulary. Deployed verbatim to
`~/.config/quickshell` by `../default.nix` (minus `dev/`) and started by niri.

## Layout

```
shell.qml        entry point — per screen: Bar, Island (+ panels), Toasts,
                 KeybindSheet, CameraImportOsd
config/          palette.json (THE colour source, also read by Nix for the
                 lock screen) · Theme.qml (tokens, metrics, motion)
services/        singletons — all state and system access lives here
components/      the widget kit (MText, MIcon, MButton, ListRow, …)
island/          Island (one popout window per screen) + IslandPanel base
panels/          the popout contents, one IslandPanel each
bar/             the bar and its widgets
overlays/        Toasts, VolumeOsd, CameraImportOsd, KeybindSheet
scripts/         shell helpers run by services (sysfs / nvidia-smi access)
dev/             test harness (not deployed)
```

Imports use the `qs.*` module root: `import qs.services`, `import qs.components`, …

## Rules of the house

- **Services own state, panels display it.** A panel never talks to Pipewire,
  NetworkManager, cliphist, … directly — it calls a service.
- **Per-screen vs global.** Windows are per screen (`Variants` in shell.qml);
  services and IPC handlers are singletons, so they exist once. Popouts are
  keyed by screen (`Popouts.open(screen, id, anchor)`), so monitors never open
  each other's panels. Windows key off the `modelData` screen they were made
  for, never their own `screen` property (it re-notifies when the window maps,
  which re-enters bindings).
- **Lists use `ScriptModel { objectProp: "<id>" }`** so rows are kept and
  updated in place instead of rebuilt (scroll position, expansion state and
  animations survive refreshes).
- **Hover rows rest on an opaque colour** (`ListRow`, `MIconButton.restColor`):
  animating a colour to `"transparent"` flashes through black.
- **Persistent state** goes through a `FileView` + `JsonAdapter` under
  `$XDG_STATE_HOME/quickshell/` (settings.json, notifications.json,
  clip-pins/). Writes are deferred with a short timer: calling
  `writeAdapter()` inside `onAdapterUpdated` loses a second assignment made in
  the same tick.
- **Shell commands** take values as positional arguments, never interpolated
  into the script; multi-line logic lives in `scripts/`.

## External contracts

- IPC: `qs ipc call cheatsheet open|close|toggle` (niri/super-cheatsheet-watch.py,
  Mod+/) and `qs ipc call cameraImport start|filing|progress|finish|fail`
  (camera-import).
- `swaylock-themed` (niri/default.nix) reads `.accent` from settings.json and
  maps it through palette.json.
- `shell-restart` (Mod+Shift+R) restarts the `quickshell` process.

## Testing — `dev/`

```sh
dev/run <scene> [seconds] [--old] [--keep-home] [--private-bus] [--real-home]
dev/compare <scene-a> <scene-b>
```

`dev/run` mirrors this tree into `$XDG_RUNTIME_DIR/qs-dev/root-<scene>` with
`dev/scenes/<scene>.qml` as the entry point, so a scene can build any part of
the shell and drive it (`Popouts.open(...)`, service calls, `qs ipc`). By
default `HOME` is a throwaway copy of your real quickshell state and cliphist
db, so tests never write real state. `--private-bus` runs under
`dbus-run-session` (to own the notification server while the real bar holds
it); `--old` runs the scene against the previous shell (`../quickshell`) for
side-by-side checks. Scenes take screenshots with `Snap` (grim) into the
output dir; `dev/compare` pixel-diffs two scenes' screenshots (ImageMagick).
grim / ImageMagick / wtype come from the flake's nixpkgs if not installed.

Scenes: `kit` (all components), `settings` (migration + reload), `services`
(+ `services-old`), `island` (morph open / switch / close), `bar` (+ `bar-old`,
pixel-identical), `minimap` (4x-inspectable snap), `panels` (+ `panels-old`), `control` (sections, scanning,
real Escape via wtype — set `QS_DEV_WTYPE`), `notify` (daemon, rules, updates,
bursts; needs `--private-bus`), `clip` (pins), `fans` (write-hold logic, no hardware writes), `misc` (settings view, confirm
morph, tray menu, clock, cheatsheet + cameraImport IPC), `osd` (volume OSD:
placement under the pill, hide delay, suppressed while a panel is open), `frames` (island
render timing per panel, `PANEL=<id>`), `full` (load check).

Visual checks need the monitor on: while it is blanked (swayidle / DPMS) niri
sends no frame callbacks, windows render about once a second, and screenshots
show stale frames. Logic checks (TEST lines) are unaffected.

## Migration from the previous shell

On first start the services migrate the old `~/.cache/quickshell` state:
accent, background and notification preferences → settings.json; notification
history → notifications.json; clipboard pins (index + files) → clip-pins/.
The old files are left in place.
