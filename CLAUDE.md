# dotborder: agent instructions

You maintain `dotborder`, a Swift focus border for AeroSpace on macOS. Read `README.md` first.

## Layout

- `Sources/DotborderCore`: pure logic, no AppKit: `Config` (arguments), `Geometry` (frames, AeroSpace's parked windows), `BorderModel` (what the border does for each read of the focused window), `AeroEvent` (parsing `aerospace subscribe`), `Burst` (follow-up reads).
- `Sources/dotborder`: the AppKit shell: `BorderWindow` (the one click-through window), `AeroSpaceFeed` (the `aerospace subscribe` child, restarted with backoff), `Controller` (events -> bursts of reads -> model -> window).
- `Sources/dotborder-tests`: the checks (`swift run dotborder-tests`, no XCTest needed).

## Hard-won facts

- AeroSpace's window ids are CoreGraphics window ids; a window's frame comes from `CGWindowListCopyWindowInfo([.optionIncludingWindow], id)`, no permission needed.
- AeroSpace parks the windows of hidden workspaces in a screen corner: a window is "shown" when a third of it is on a screen.
- `NSWindow.order(.above, relativeTo:)` sent as a window arrives can land before it is composed and then holds nothing: repeat it on every read of the burst.
- Another window with the very same frame is still a change (the border must be ordered above it), so the model compares window ids too.
- The outline is centered on the window's edge (half over the window), like JankyBorders.
- Measure visual changes: record with `screencapture -v -V 9 file.mov`, analyze frames with ffmpeg. Single-frame blips of the metric are noise; compare against JankyBorders with the same script and look at gaps of 30 ms or more.
- Never start `borders` (or any daemon) in the foreground of a shell: it stays running and blocks the shell.

## Checks

`swift run dotborder-tests` must pass. Add a failing check before each fix.

## Rules for every change

- Conventional Commits (`feat(scope): ...`), one reviewable unit per commit with its tests and docs. No AI attribution or `Co-Authored-By` lines.
- Artifacts (code, comments, docs, commit messages) are in English; the maintainer talks to you in Spanish.
- This repository is public: never commit secrets, tokens, IPs of a private network, or precise personal coordinates.
- Nothing hardcoded to one machine, repository, space or agent name: it must work for anyone.
- Cost matters more than features: keep idle CPU near zero and RAM small. Prefer events over polling; any polling needs a stated reason and a measured cost. Never leave a background process looping, hung or forgotten.
- Work on a branch, push it as `ci/<name>` to run CI, merge to `main` only when green. Do not push to `main` untested.
- The `dotfiles` repository pins this one as a submodule (`mac/tools/<name>`); after merging here, bump the pointer there.
