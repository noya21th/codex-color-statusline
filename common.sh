# build.sh / install.sh / uninstall.sh 共用
WORK="${HOME}/.cache/codex-color-build"
STANDALONE="${HOME}/.codex/packages/standalone"
PATCH_NAME="status-line-threshold-colors.patch"

# 给了版本号就用它,否则取官方 current 指向的版本(如 0.154.0)
resolve_version() {
  if [ -n "${1:-}" ]; then
    echo "$1"
  else
    basename "$(readlink "${STANDALONE}/current")" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/'
  fi
}

# 官方安装目录,如 ~/.codex/packages/standalone/releases/0.154.0-aarch64-apple-darwin
release_dir() {
  ls -d "${STANDALONE}/releases/$1-"* 2>/dev/null | head -1
}

sha256() {
  shasum -a 256 "$1" | cut -d' ' -f1
}
