#!/usr/bin/env bash
# 启动一个「带远程调试 + 独立持久 profile」的 Chrome，供 Chrome MCP 通过 CDP 直连。
# 在这个窗口里登录一次你要自动化的网站（淘宝/小红书/...），登录态会保存在 profile 里，下次无需重登。
set -euo pipefail

PORT="${CHROME_MCP_PORT:-9222}"
PROFILE="${CHROME_MCP_PROFILE:-$HOME/.chrome-mcp-profile}"

# 自动探测 Chrome（macOS / Linux），可用 CHROME_BIN 覆盖
MAC_APP="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CHROME="${CHROME_BIN:-}"
if [ -z "$CHROME" ]; then
  if [ -x "$MAC_APP" ]; then
    CHROME="$MAC_APP"
  else
    for c in google-chrome google-chrome-stable chromium-browser chromium; do
      if command -v "$c" >/dev/null 2>&1; then CHROME="$(command -v "$c")"; break; fi
    done
  fi
fi
if [ -z "$CHROME" ] || [ ! -x "$CHROME" ]; then
  echo "❌ 找不到 Chrome${CHROME:+：$CHROME}"
  echo "   请用环境变量指定，例如："
  echo "   CHROME_BIN=\"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome\" $0"
  exit 1
fi

mkdir -p "$PROFILE"

# 端口占用检查（区分「自己之前启的 Chrome」和「别的程序」）
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  HOLDER="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $1" (PID "$2")"}')"
  if curl -s --noproxy '*' --max-time 5 "http://127.0.0.1:$PORT/json/version" | grep -q "Browser"; then
    echo "✅ 端口 ${PORT} 上已有一个调试版 Chrome 在运行（${HOLDER}），直接复用即可，无需重启。"
    echo "   如需换端口：CHROME_MCP_PORT=9333 $0"
    exit 0
  else
    echo "❌ 端口 ${PORT} 被别的程序占用（${HOLDER}），不是调试版 Chrome。"
    echo "   换一个端口：CHROME_MCP_PORT=9333 $0   （记得 Codex 配置里的 --cdp-endpoint 也改成同一端口）"
    exit 1
  fi
fi

echo "🚀 启动调试版 Chrome"
echo "   CDP 端口 : $PORT"
echo "   持久 profile: $PROFILE"

# 脱离终端/会话独立启动（关终端、agent 会话结束都不会连坐杀掉 Chrome），立即返回。
if [ "$CHROME" = "$MAC_APP" ]; then
  # macOS 标准 Chrome：用 `open -na` 起独立实例（与终端解耦，最稳）
  open -na "Google Chrome" --args \
    --remote-debugging-port="$PORT" \
    --user-data-dir="$PROFILE" \
    --no-first-run --no-default-browser-check about:blank
else
  # Linux / 自定义 Chrome 路径：nohup 后台启动
  nohup "$CHROME" \
    --remote-debugging-port="$PORT" \
    --user-data-dir="$PROFILE" \
    --no-first-run --no-default-browser-check about:blank >/dev/null 2>&1 &
fi

# 等 CDP 真正起来（最多 ~15s），起来了再返回，方便 agent 顺序往下走
for _ in $(seq 1 30); do
  if curl -s --noproxy '*' --max-time 2 "http://127.0.0.1:$PORT/json/version" | grep -q "Browser"; then
    echo "✅ 已启动并就绪（CDP 端口 ${PORT}，后台运行，关终端不死）。"
    echo "   ➜ 现在请在弹出的 Chrome 窗口里【登录一次】你要自动化的网站，登录态会长期保存。"
    echo "   ➜ 配置完成后保持它开着。验证：CHROME_MCP_PORT=$PORT bash verify.sh"
    exit 0
  fi
  sleep 0.5
done
echo "⚠️ Chrome 已启动，但 ${PORT} 端口 15s 内未就绪。常见原因：系统/公司代理拦了本地连接，或端口被占。"
echo "   排查：lsof -nP -iTCP:$PORT -sTCP:LISTEN  ；换端口：CHROME_MCP_PORT=9333 $0"
exit 0
