# Re-verification 2 on main 449a77e
Tart VM macOS 26.6.2 1600x1000, Release build 449a77e (executable SHA-256 2ce58c97...348c, identical on host and guest). 
| Issue | Result |
|---|---|
| 181 | PASS (Escape and arrow keys act right after open; CGEvent keys) |
| 182 | FAIL (no Accessibility: trash AX x=981 outside panel x615..985, note shown) |
| 191 | FAIL (panel stayed drawn 38 s after drag-out removal in 4 of 4 trials; fresh-app control hid) |
| 197 | PASS (margin clicks launch at icon size 128 and 16; size 128 panel bottom = 1000) |
| 186 | FAIL (standard Dock menu opened and stayed open; App Expose not observed; no alert) |
