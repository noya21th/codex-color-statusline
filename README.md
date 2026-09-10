<p align="center">
  <img src="docs/banner.png" alt="codex-color-statusline: color-coded usage for the Codex CLI status line" width="100%">
</p>

<p align="center"><b>English</b> | <a href="README.zh-CN.md">中文</a></p>

# codex-color-statusline

Color-coded usage in the [OpenAI Codex CLI](https://github.com/openai/codex) status line: context, 5-hour and weekly limits turn green → yellow → orange → red as headroom runs out.

<p align="center">
  <img src="docs/preview.png" alt="Simulated Codex status lines at different usage levels" width="100%">
</p>
<p align="center"><sub>Simulated preview. Top line: official colors. Below: the patched status line at different usage levels.</sub></p>

Codex can already show `Context N% used`, `5h N% left` and `weekly N% left` in its footer, but it colors each item by type, so the color never changes as you run low. There is no setting for this, so this project rebuilds Codex from the official source with a one-file patch.

| | Green | Yellow | Orange | Red |
|---|---|---|---|---|
| 5h / weekly **left** | above 50% | 31–50% | 16–30% | 15% or less |
| Context **used** | below 50% | 50–69% | 70–84% | 85% or more |

Both rows use one scale (used = 100 − left). Context is per conversation. The 5h and weekly limits are shared by your whole account and refresh when Codex starts or finishes a reply.

> Unofficial and not affiliated with OpenAI. The official binary is backed up before it is replaced and can be restored at any time.

## Requirements

- macOS with Codex CLI from the official standalone installer (it lives in `~/.codex/packages/standalone`). Tested on Apple Silicon with Codex CLI 0.154.0.
- Xcode Command Line Tools: `xcode-select --install`
- CMake: `brew install cmake`
- Rust: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`. The exact toolchain Codex pins is installed by the build script.
- About 10 GB of free disk space. The first build plus tests took about 30 minutes on Apple Silicon.

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

A Codex update installs into a new version folder, so you are back on the official binary (no colors, nothing breaks). Run `./build.sh && ./install.sh` again. If `build.sh` says the patch does not apply, upstream changed the footer styling code and the patch needs an update.

## How it works

- `patches/status-line-threshold-colors.patch` touches one file, `codex-rs/tui/src/bottom_pane/status_line_style.rs`, and adds unit tests. It reads the percentage from the text of the four usage items; anything it cannot parse keeps the theme color.
- `build.sh [version]` downloads the matching `rust-v<version>` source tag, applies the patch, builds `codex` and runs the patch tests. The tag's `Cargo.lock` lists workspace crates as `0.0.0`, so the script bumps only those entries and stops if any third-party dependency would change.
- `install.sh [version]` backs up the official binary (only if it is signed by OpenAI) to `~/.cache/codex-color-build/backup/<version>/`, then replaces it with an atomic rename so running sessions are unaffected.
- `uninstall.sh [version]` checks the backup's checksum and restores it.

Source and build output live in `~/.cache/codex-color-build/`. Once you are happy with the install you can delete the `target` folder there to free several GB.

## License

[Apache-2.0](LICENSE), same as Codex. See [NOTICE](NOTICE).
