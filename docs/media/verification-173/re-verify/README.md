# Re-verification of fixed bugs on main 9045432

Environment: Tart headless VM (macOS 26.6.2, 1600x1000). Release build of 9045432 (executable SHA-256 67f63d77...6bb6, identical on host and guest). Launch via `open -n` (no Accessibility) or by direct exec from ssh (Accessibility inherited). VNC frames lag the real state by a few seconds; AX values and CGWindowList logs were used as the reference.

| Issue | Result | Evidence |
|---|---|---|
| 181 folder popover keys | FAIL | 181-popover-open.png, 181-popover-after-esc.png: popover (layer 21, 346x221) stayed onscreen 2 s after Escape (CGEvent and VNC), key window stayed the panel |
| 182 trash pushed out | FAIL | 182-fail-trash-outside-panel.png, 182-log.txt: panel x610..990, trash AX x=1014 |
| 186 Show All Windows | not confirmed | 186-context-menu-show-all-windows.png, 186-standard-dock-menu-opened.png: item enabled, standard Dock menu opened, no error alert, App Expose not observed |
| 187 window list in menu | PASS (item present) | 187-context-menu-window-list-item.png |
| 190 login launch | PASS | 190-log.txt, 190-login-launch-panel-only.png, 190-normal-launch-window.png |
| 191 autohide re-arm | FAIL | 191-22s-after-dropout.png, 191-45s-after-dropout.png, 191-control.png |
