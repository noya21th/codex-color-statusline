#!/bin/bash
# 把编好的彩色底栏 codex 原地换进官方安装目录(官方原版先备份)
# Usage / 用法: ./install.sh [version]   默认用当前官方安装的版本
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
source "${HERE}/common.sh"
OPENAI_TEAM_ID="2DC432GLL2"

VER="$(resolve_version "${1:-}")"
REL="$(release_dir "${VER}")"
[ -n "${REL}" ] || { echo "❌ Codex install not found / 没找到官方安装目录: ${STANDALONE}/releases/${VER}-*"; exit 1; }
BIN="${REL}/bin/codex"
BUILT="${WORK}/codex-rust-v${VER}/codex-rs/target/release/codex"
BACKUP="${WORK}/backup/${VER}/codex"

[ -x "${BUILT}" ] || { echo "❌ Not built yet, run ./build.sh ${VER} first / 还没编译,先跑 build.sh"; exit 1; }
"${BUILT}" --version | grep -qx "codex-cli ${VER}" || { echo "❌ Built binary is not ${VER} / 编出来的版本不对: $("${BUILT}" --version)"; exit 1; }

BUILT_SHA="$(sha256 "${BUILT}")"
if [ "$(sha256 "${BIN}")" = "${BUILT_SHA}" ]; then
  echo "Already installed / 已经是彩色底栏版 ${VER}"
  exit 0
fi

# 只备份 OpenAI 签名的官方原版,避免把旧的自编版当成原版存起来
if [ ! -f "${BACKUP}" ]; then
  if ! codesign -dv "${BIN}" 2>&1 | grep -qx "TeamIdentifier=${OPENAI_TEAM_ID}"; then
    echo "❌ ${BIN} is not signed by OpenAI and has no backup, stopping / 不是官方签名版又没有备份,停止" >&2
    exit 1
  fi
  mkdir -p "$(dirname "${BACKUP}")"
  cp -p "${BIN}" "${BACKUP}"
  sha256 "${BACKUP}" > "${BACKUP}.sha256"
  echo "== Official binary backed up / 官方原版已备份: ${BACKUP}"
fi

# 用 mv 换(新 inode),正在运行的 Codex 不受影响
cp "${BUILT}" "${BIN}.color-tmp"
chmod 755 "${BIN}.color-tmp"
mv -f "${BIN}.color-tmp" "${BIN}"
[ "$(sha256 "${BIN}")" = "${BUILT_SHA}" ] || { echo "❌ Checksum mismatch after install / 替换后校验不一致"; exit 1; }
"${BIN}" --version
echo "✅ Installed / 已安装 ${VER}. Restart Codex / 重开 Codex 生效. Undo / 还原: ./uninstall.sh ${VER}"
