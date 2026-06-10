#!/usr/bin/env bash
# 自检：确认「Chrome 调试端口」和「@playwright/mcp」都就绪。两项都 ✅ 即可在客户端里使用。
PORT="${CHROME_MCP_PORT:-9222}"
MCP_PKG="@playwright/mcp@${CHROME_MCP_VERSION:-0.0.76}"
ok=0

echo "1) 检查 Chrome 远程调试端口 $PORT ..."
VER="$(curl -s --noproxy '*' "http://127.0.0.1:$PORT/json/version" 2>/dev/null)"
if printf '%s' "$VER" | grep -q "Browser"; then
  echo "   ✅ 在线：$(printf '%s' "$VER" | python3 -c "import sys,json;print(json.load(sys.stdin).get('Browser',''))" 2>/dev/null)"
  printf '%s' "$VER" | grep -q "webSocketDebuggerUrl" && echo "   ✅ CDP WebSocket 可用（Playwright 就是连这个）"
else
  echo "   ❌ 连不上。请先运行：bash scripts/start-chrome.sh"
  HOLDER="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $1" (PID "$2")"}')"
  [ -n "$HOLDER" ] && echo "   ℹ️ 端口 ${PORT} 当前被占用：${HOLDER}（不是调试版 Chrome）"
  ok=1
fi

echo "2) 检查 Node / $MCP_PKG ...（首次运行会下载包，可能需要 1-3 分钟）"
if command -v npx >/dev/null 2>&1; then
  if npx -y "$MCP_PKG" --version >/dev/null 2>&1; then
    echo "   ✅ $MCP_PKG 可用：$(npx -y "$MCP_PKG" --version 2>/dev/null)"
  else
    echo "   ❌ $MCP_PKG 拉取失败。国内网络建议先切镜像再重跑："
    echo "      npm config set registry https://registry.npmmirror.com"
    ok=1
  fi
else
  echo "   ❌ 没有 npx，请先安装 Node.js (https://nodejs.org)"; ok=1
fi

echo "3) 检查 MCP 注册情况（信息项，不影响通过）..."
FOUND=0
if command -v codex >/dev/null 2>&1; then
  if codex mcp list 2>/dev/null | grep -q "chrome"; then
    echo "   ✅ Codex 已注册 chrome"
    grep -q "startup_timeout_sec" "$HOME/.codex/config.toml" 2>/dev/null \
      || echo "   ⚠️ ~/.codex/config.toml 的 [mcp_servers.chrome] 缺 startup_timeout_sec = 120，建议补上（防 npx 启动超时）"
    FOUND=1
  fi
fi
if command -v claude >/dev/null 2>&1; then
  claude mcp list 2>/dev/null | grep -q "chrome" && { echo "   ✅ Claude Code 已注册 chrome"; FOUND=1; }
fi
if [ -f "$HOME/.cursor/mcp.json" ]; then
  grep -q '"chrome"' "$HOME/.cursor/mcp.json" 2>/dev/null && { echo "   ✅ Cursor 已注册 chrome"; FOUND=1; }
fi
[ $FOUND -eq 0 ] && echo "   ℹ️ 尚未在任何已知客户端里发现 chrome，请按 README 第 2 步注册"

echo "4) 检查旧版残留（扩展+bridge+12306 老架构，信息项）..."
OLD=""
curl -s --noproxy '*' --max-time 2 "http://127.0.0.1:12306/ping" 2>/dev/null | grep -q "pong" && OLD="${OLD}bridge(12306端口) "
command -v codex >/dev/null 2>&1 && codex mcp list 2>/dev/null | grep -q "chrome-mcp-server" && OLD="${OLD}Codex注册(chrome-mcp-server) "
[ -d "$HOME/.codex/mcp-chrome-bridge" ] && OLD="${OLD}目录(~/.codex/mcp-chrome-bridge) "
if [ -n "$OLD" ]; then
  echo "   ⚠️ 发现旧版 Chrome MCP 残留：${OLD}"
  echo "      两套并存容易让 AI 调错工具，建议清理，步骤见 README「卸载 / 从旧版迁移」"
else
  echo "   ✅ 无旧版残留"
fi

echo ""
[ $ok -eq 0 ] && echo "🎉 全部就绪。重启客户端会话后试试：用 chrome 列出当前窗口和标签页。" || echo "⚠️ 有未通过项，按上面提示修复后重跑：bash verify.sh"
exit $ok
