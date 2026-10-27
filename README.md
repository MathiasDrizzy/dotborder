# dotborder

A focus border for [AeroSpace](https://github.com/nikitabobko/AeroSpace) windows on macOS, in Swift (AppKit only, no dependencies). A replacement for JankyBorders that does not flicker when you change workspace.

- **Event-driven, no polling.** AeroSpace pushes an event the instant the focus or workspace changes (`aerospace subscribe`); dotborder reads the window's frame (`CGWindowList`, no permission needed), moves one click-through window, kept above the normal windows by its window level.
- **No macOS permission** (no Accessibility, no Screen Recording).
- **Small**: ~40 MB resident, 0 % CPU while idle (JankyBorders held 115-180 MB here).
- **Smooth workspace switches**: the border appears at once (`fade_in=<ms>` brings back a fade, but at fast switches it leaves the window without a border for the length of the fade: 270-300 ms measured). The border is a window level above the normal windows, not an order relative to the focused window: that order raced with AeroSpace and WindowServer, and fast switches left the border under the window for hundreds of milliseconds. Hiding waits a quarter of a second, because AeroSpace parks the old window before it reports the new focus and, under load, the report can lag. Measured by recording the screen at 60 fps over six workspace switches: JankyBorders left the window without a border for 50-84 ms at each switch, dotborder for at most a frame or two (and for none at most switches).

```sh
scripts/bundle.sh ~/Applications     # builds dotborder.app
~/Applications/dotborder.app/Contents/MacOS/dotborder active_color=0xccb48efa width=2.0
swift run dotborder-tests            # the checks
```

Arguments are `key=value` (the names are JankyBorders'): `active_color=0xAARRGGBB`, `width=<points>`, `radius=<points>` (the windows' corner radius, default 14), `fade_in=<ms>` (default 0). `DOTBORDER_DEBUG=1` prints every decision with its time.

[dotfiles](https://github.com/MathiasDrizzy/dotfiles) builds it and starts it at login with a launch agent.
