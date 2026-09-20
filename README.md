<p align="center">
  <img src="docs/banner.png" alt="codex-color-statusline: color-coded usage for the Codex CLI status line" width="100%">
</p>

<p align="center"><b>English</b> | <a href="README.zh-CN.md">中文</a></p>

# codex-color-statusline

Two things the [OpenAI Codex CLI](https://github.com/openai/codex) status line cannot do on its own:

1. **Color by headroom** — context and usage limits turn green → yellow → orange → red as you run low.
2. **A usage meter with a reset countdown** — limits render the way Claude Code shows them, with a bar, the percent *used*, and how long until the window resets.

```
gpt-5.6-sol high · Context 0% used · 5h ░░░░░░░░░░ 5% (resets in 3h 9m) · weekly █░░░░░░░░░ 15% (resets in 18h 58m)
```

<p align="center">
  <img src="docs/preview.png" alt="Simulated Codex status lines at different usage levels" width="100%">
</p>
<p align="center"><sub>Simulated preview of the color thresholds. Top line: official colors. Below: the patched status line at different usage levels.</sub></p>

Codex already shows `Context N% used`, `5h N% left` and `weekly N% left` in its footer, but it colors each item by type, so the color never changes as you run low, and it never tells you *when* a limit resets — for that you have to run `/status`. There is no setting for either, so this project rebuilds Codex from the official source.

| | Green | Yellow | Orange | Red |
|---|---|---|---|---|
| **Used** | below 50% | 50–69% | 70–84% | 85% or more |

Everything is on one scale. Note the patched limits show the percent **used**, not left, so the number reads the same way as the bar beside it — where upstream said `weekly 85% left`, you now see `weekly █░░░░░░░░░ 15%`.

Context is per conversation. The 5h and weekly limits are shared by your whole account.

> Unofficial and not affiliated with OpenAI. The official binary is backed up before it is replaced and can be restored at any time.

## Good to know

- **The status line is not a ticking clock.** It is redrawn on events — startup, keystrokes, a finished reply — so the countdown does not tick down on its own. It is computed against the current time whenever it redraws, so it stays accurate even when the underlying usage snapshot is stale.
- **The full line is wide.** With both limits shown it runs about 116 columns and a narrow terminal will cut off the tail. Dropping the usage items you do not need from `status_line` is the simplest fix.
- **When a reset time is unavailable**, or the window has already passed, the `(resets in …)` clause is dropped and you are left with the bar and the percentage.

## Requirements

- macOS with Codex CLI from the official standalone installer (it lives in `~/.codex/packages/standalone`). Tested on Apple Silicon with Codex CLI 0.155.1.
- Xcode Command Line Tools: `xcode-select --install`
- CMake: `brew install cmake`
- Rust: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`. The exact toolchain Codex pins is installed by the build script.
- About 10 GB of free disk space — the build directory peaks around 8.6 GB. A clean build took about 11 minutes on Apple Silicon.

## Install

1. Turn on the usage items in `~/.codex/config.toml` (skip if your status line already shows them):

   ```toml
   [tui]
   status_line = ["model-with-reasoning", "context-used", "five-hour-limit", "weekly-limit"]
   status_line_use_colors = true
   ```

2. Build and install:

   ```bash
   git clone https://github.com/noya21th/codex-color-statusline.git
   cd codex-color-statusline
   ./build.sh     # builds the patched Codex for your installed version and runs its tests
   ./install.sh   # backs up the official binary, then swaps in the patched one
   ```

3. Restart Codex. Windows opened before step 2 keep running the old binary until you reopen them.

## Uninstall

```bash
./uninstall.sh
```

## After updating Codex

**A Codex update silently puts you back on the official binary.** It installs into a new version folder and repoints `current`, so nothing breaks — but the colors and the meters are gone, with no warning. If the status line stops reacting to your usage, that is what happened.

Run `./build.sh && ./install.sh` again. If `build.sh` says a patch does not apply, upstream changed the code it touches and the patch needs an update.

## How it works

Two patches, applied in the order listed in `common.sh`:

- `patches/status-line-threshold-colors.patch` — threshold colors. Touches one file, `codex-rs/tui/src/bottom_pane/status_line_style.rs`, and adds unit tests.
- `patches/status-line-weekly-countdown.patch` — the meter and countdown. Builds on the first patch, since rendering a limit as `15% (resets in …)` means its headroom can no longer be read back out of the text; the percentage is handed to the footer directly instead. Upstream keeps only a preformatted reset string, so this patch also stores the raw reset instant alongside it.

Supporting scripts:

- `build.sh [version]` downloads the matching `rust-v<version>` source tag, applies both patches, builds `codex` and runs the patch tests. The tag's `Cargo.lock` lists workspace crates as `0.0.0`, so the script bumps only those entries and stops if any third-party dependency would change.
- `install.sh [version]` backs up the official binary (only if it is signed by OpenAI) to `~/.cache/codex-color-build/backup/<version>/`, then replaces it with an atomic rename so running sessions are unaffected.
- `uninstall.sh [version]` checks the backup's checksum and restores it.

Source and build output live in `~/.cache/codex-color-build/`. Once you are happy with the install you can delete the `target` folder there to free several GB.

## License

[Apache-2.0](LICENSE), same as Codex. See [NOTICE](NOTICE).
