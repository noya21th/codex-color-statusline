#!/bin/bash
# 把 Codex 换回官方原版(用 install.sh 留下的备份)
# Usage / 用法: ./uninstall.sh [version]   默认用当前官方安装的版本
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
source "${HERE}/common.sh"

VER="$(resolve_version "${1:-}")"
REL="$(release_dir "${VER}")"
[ -n "${REL}" ] || { echo "❌ Codex install not found / 没找到官方安装目录: ${STANDALONE}/releases/${VER}-*"; exit 1; }
BIN="${REL}/bin/codex"
BACKUP="${WORK}/backup/${VER}/codex"

[ -f "${BACKUP}" ] || { echo "❌ No backup for ${VER} / 没有 ${VER} 的官方备份(可能从没装过彩色版)"; exit 1; }
WANT="$(cat "${BACKUP}.sha256")"
[ "$(sha256 "${BACKUP}")" = "${WANT}" ] || { echo "❌ Backup checksum mismatch, stopping / 备份文件校验不对,停止还原"; exit 1; }
if [ "$(sha256 "${BIN}")" = "${WANT}" ]; then
  echo "Already official / 已经是官方原版 ${VER}"
  exit 0
fi

# 用 mv 换(新 inode),正在运行的 Codex 不受影响
cp -p "${BACKUP}" "${BIN}.official-tmp"
mv -f "${BIN}.official-tmp" "${BIN}"
[ "$(sha256 "${BIN}")" = "${WANT}" ] || { echo "❌ Checksum mismatch after restore / 还原后校验不一致"; exit 1; }
echo "✅ Restored official ${VER} / 已还原官方原版. Restart Codex / 重开 Codex 生效"
