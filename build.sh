#!/bin/bash
# 按官方 Codex 版本拉源码 → 套彩色底栏补丁 → 编译 → 跑补丁单测
# Usage / 用法: ./build.sh [version]   默认用当前官方安装的版本
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
source "${HERE}/common.sh"
export PATH="${HOME}/.cargo/bin:${PATH}"

VER="$(resolve_version "${1:-}")"
SRC="${WORK}/codex-rust-v${VER}"

command -v rustup >/dev/null || { echo "❌ rustup not found, install Rust first: https://rustup.rs / 没找到 rustup,先装 Rust"; exit 1; }
mkdir -p "${WORK}"

if [ ! -d "${SRC}" ]; then
  echo "== Downloading Codex ${VER} source / 下载源码"
  curl -fsSL "https://codeload.github.com/openai/codex/tar.gz/refs/tags/rust-v${VER}" | tar xz -C "${WORK}"
fi

cd "${SRC}"
for PATCH_FILE in "${PATCH_NAMES[@]}"; do
  PATCH="${HERE}/patches/${PATCH_FILE}"
  if git apply --check -R "${PATCH}" 2>/dev/null; then
    echo "== Patch already applied / 补丁已在源码里: ${PATCH_FILE}"
  elif git apply --check "${PATCH}" 2>/dev/null; then
    echo "== Applying patch / 套补丁: ${PATCH_FILE}"
    git apply "${PATCH}"
  else
    echo "❌ Patch does not apply to ${VER} / 补丁套不上 ${VER}: ${PATCH_FILE}" >&2
    echo "   Upstream changed the code this patch touches / 上游改了这个补丁碰的代码,需要重新适配" >&2
    exit 1
  fi
done

cd "${SRC}/codex-rs"
# 按 rust-toolchain.toml 装好 Codex 指定的 Rust 版本
rustup toolchain install

# 源码 tag 的 Cargo.lock 里工作区 crate 还是 0.0.0,--locked 会直接失败。
# 只更新工作区条目,并确认第三方依赖一行没动。
LOCK_ORIG="${WORK}/Cargo.lock.orig-${VER}"
[ -f "${LOCK_ORIG}" ] || cp -p Cargo.lock "${LOCK_ORIG}"
cargo update --workspace
python3 - "${LOCK_ORIG}" Cargo.lock "${VER}" <<'PY'
import sys
orig, new, ver = sys.argv[1:4]
a = open(orig).read().splitlines()
b = open(new).read().splitlines()
if len(a) != len(b):
    sys.exit(f"❌ Cargo.lock line count changed ({len(a)}→{len(b)}) / 行数变了,有依赖被改动")
changed = [(x, y) for x, y in zip(a, b) if x != y]
bad = [p for p in changed if p != ('version = "0.0.0"', f'version = "{ver}"')]
if bad:
    sys.exit(f"❌ Unexpected Cargo.lock changes / 出现非工作区版本号的改动: {bad[:3]}")
print(f"== Cargo.lock: {len(changed)} workspace versions bumped, third-party deps unchanged / 第三方依赖未动")
PY

echo "== Building, the first build takes a while / 编译(首次较久)"
cargo build --release --locked -p codex-cli --bin codex
echo "== Running patch tests / 跑补丁单测"
cargo test --release --locked -p codex-tui --lib status_line

"${SRC}/codex-rs/target/release/codex" --version
echo "✅ Built / 编译完成: ${SRC}/codex-rs/target/release/codex"
echo "   Next / 下一步: ./install.sh ${VER}"
