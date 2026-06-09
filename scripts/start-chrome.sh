#!/usr/bin/env bash
# 启动一个「带远程调试 + 独立持久 profile」的 Chrome，供 Chrome MCP 通过 CDP 直连。
# 在这个窗口里登录一次你要自动化的网站（淘宝/小红书/...），登录态会保存在 profile 里，下次无需重登。
set -euo pipefail

PORT="${CHROME_MCP_PORT:-9222}"
PROFILE="${CHROME_MCP_PROFILE:-$HOME/.chrome-mcp-profile}"

# 自动探测 Chrome（macOS 默认路径），可用 CHROME_BIN 覆盖
CHROME="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [ ! -x "$CHROME" ]; then
  echo "❌ 找不到 Chrome：$CHROME"
  echo "   请用环境变量指定，例如："
  echo "   CHROME_BIN=\"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome\" $0"
  exit 1
fi

mkdir -p "$PROFILE"

# 端口占用检查（区分「自己之前启的 Chrome」和「别的程序」）
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  HOLDER="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $1" (PID "$2")"}')"
  if curl -s "http://127.0.0.1:$PORT/json/version" | grep -q "Browser"; then
    echo "✅ 端口 $PORT 上已有一个调试版 Chrome 在运行（$HOLDER），直接复用即可，无需重启。"
    echo "   如需换端口：CHROME_MCP_PORT=9333 $0"
    exit 0
  else
    echo "❌ 端口 $PORT 被别的程序占用（$HOLDER），不是调试版 Chrome。"
    echo "   换一个端口：CHROME_MCP_PORT=9333 $0   （记得 Codex 配置里的 --cdp-endpoint 也改成同一端口）"
    exit 1
  fi
fi

echo "🚀 启动调试版 Chrome"
echo "   CDP 端口 : $PORT"
echo "   持久 profile: $PROFILE"
echo "   ➜ 在弹出的窗口里登录你要自动化的网站，登录态会长期保存在这个 profile。"
echo "   ➜ 保持此窗口开着；Codex 里的 chrome MCP 会通过 CDP 连到它。"
exec "$CHROME" \
  --remote-debugging-port="$PORT" \
  --user-data-dir="$PROFILE" \
  --no-first-run \
  --no-default-browser-check \
  "about:blank"
