<p align="center">
  <img src="docs/banner.png" alt="codex-color-statusline：给 Codex CLI 底栏额度上色" width="100%">
</p>

<p align="center"><a href="README.md">English</a> | <b>中文</b></p>

# codex-color-statusline

[OpenAI Codex CLI](https://github.com/openai/codex) 的底栏本身做不到的两件事：

1. **按余量变色** —— 上下文和额度会随着用量增加，从绿变黄、变橙、变红。
2. **表盘式额度 + 重置倒计时** —— 额度项按 Claude Code 那种样子显示：进度条、**已用**百分比、距离重置还有多久。

```
gpt-5.6-sol high · Context 0% used · 5h ░░░░░░░░░░ 5% (resets in 3h 9m) · weekly █░░░░░░░░░ 15% (resets in 18h 58m)
```

<p align="center">
  <img src="docs/preview.png" alt="不同用量下的 Codex 底栏模拟效果" width="100%">
</p>
<p align="center"><sub>配色阈值的模拟效果图。第一行是官方原配色，下面几行是补丁后在不同用量下的样子。</sub></p>

Codex 底栏本来就能显示 `Context N% used`、`5h N% left`、`weekly N% left`，但颜色只按项目类型固定，额度快用完了颜色也不变；而且它从不告诉你额度**什么时候**重置，想知道得专门敲 `/status`。这两件事都没有设置能改，所以这个项目用官方源码重新编译 Codex。

| | 绿 | 黄 | 橙 | 红 |
|---|---|---|---|---|
| **已用** | 50% 以下 | 50–69% | 70–84% | 85% 及以上 |

全部统一到一个标准。注意补丁后的额度项显示的是**已用**百分比，不是剩余——这样数字和旁边的进度条方向一致。原本的 `weekly 85% left`，现在是 `weekly █░░░░░░░░░ 15%`。

Context 每个对话单独算；5h 和 weekly 整个账号共用。

> 非官方项目，与 OpenAI 无关。替换前会先备份官方原版，随时可以还原。

## 用之前先知道这几点

- **底栏不是秒表。** 它在启动、按键、收到回复这些时机才重绘，倒计时不会自己走字。但它每次重绘都按当前时间现算，所以即使底层的额度快照是旧的，倒计时依然准。
- **整行比较长。** 两个额度项都开着大约 116 列，终端窄了会截掉尾巴。最简单的办法是从 `status_line` 里去掉用不上的项。
- **拿不到重置时间**（或窗口已经过去）时，`(resets in …)` 整段会自动省略，只剩进度条和百分比。

## 需要准备

- macOS，Codex CLI 用官方独立安装包安装（位于 `~/.codex/packages/standalone`）。已在 Apple Silicon + Codex CLI 0.155.1 上测试
- Xcode 命令行工具：`xcode-select --install`
- CMake：`brew install cmake`
- Rust：`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`。Codex 指定的 Rust 版本由编译脚本自动安装
- 约 10 GB 空闲磁盘，编译目录峰值约 8.6 GB。Apple Silicon 上完整编译约 11 分钟

## 安装

1. 在 `~/.codex/config.toml` 里打开这几项（底栏已经显示了就跳过）：

   ```toml
   [tui]
   status_line = ["model-with-reasoning", "context-used", "five-hour-limit", "weekly-limit"]
   status_line_use_colors = true
   ```

2. 编译并安装：

   ```bash
   git clone https://github.com/noya21th/codex-color-statusline.git
   cd codex-color-statusline
   ./build.sh     # 按你装的 Codex 版本编译补丁版，并跑测试
   ./install.sh   # 先备份官方原版，再换上补丁版
   ```

3. 重开 Codex。第 2 步之前就开着的窗口还在用旧程序，要关掉重开。

## 卸载

```bash
./uninstall.sh
```

## Codex 升级之后

**Codex 升级会不声不响把你换回官方版。** 它装到新的版本目录并切换 `current`，功能不受影响，但颜色和表盘都没了，而且没有任何提示。如果哪天发现底栏颜色不跟着用量变了，多半就是这个原因。

重新运行 `./build.sh && ./install.sh` 即可。如果 `build.sh` 提示某个补丁套不上，说明上游改了这个补丁涉及的代码，补丁需要更新。

## 原理

两个补丁，按 `common.sh` 里列出的顺序套用：

- `patches/status-line-threshold-colors.patch` —— 阈值配色。只改 `codex-rs/tui/src/bottom_pane/status_line_style.rs` 一个文件，并附带单元测试。
- `patches/status-line-weekly-countdown.patch` —— 表盘和倒计时。建立在第一个补丁之上：额度项一旦显示成 `15% (resets in …)`，余量就没法再从文字里读出来了，所以改成把百分比直接交给底栏。另外上游只保留了格式化好的重置时间字符串，这个补丁会把原始时刻一并存下来。

配套脚本：

- `build.sh [版本]` 下载对应的 `rust-v<版本>` 源码，按序打两个补丁，编译 `codex`，跑补丁测试。源码里 `Cargo.lock` 的工作区 crate 版本是 `0.0.0`，脚本只更新这些条目，第三方依赖有任何变动就停止。
- `install.sh [版本]` 先把官方原版（仅限 OpenAI 签名的）备份到 `~/.cache/codex-color-build/backup/<版本>/`，再用原子改名替换，正在运行的 Codex 不受影响。
- `uninstall.sh [版本]` 核对备份校验值后还原。

源码和编译产物放在 `~/.cache/codex-color-build/`。确认好用后可以删掉里面的 `target` 文件夹，能腾出好几 GB。

## 许可证

[Apache-2.0](LICENSE)，与 Codex 一致。另见 [NOTICE](NOTICE)。
