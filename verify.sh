#!/usr/bin/env bash
# 自检：确认「Chrome 调试端口」和「@playwright/mcp」都就绪。两项都 ✅ 即可在 Codex 里使用。
PORT="${CHROME_MCP_PORT:-9222}"
ok=0

echo "1) 检查 Chrome 远程调试端口 $PORT ..."
VER="$(curl -s --noproxy '*' "http://127.0.0.1:$PORT/json/version" 2>/dev/null)"
if printf '%s' "$VER" | grep -q "Browser"; then
  echo "   ✅ 在线：$(printf '%s' "$VER" | python3 -c "import sys,json;print(json.load(sys.stdin).get('Browser',''))" 2>/dev/null)"
  printf '%s' "$VER" | grep -q "webSocketDebuggerUrl" && echo "   ✅ CDP WebSocket 可用（Playwright 就是连这个）"
else
  echo "   ❌ 连不上。请先运行：bash scripts/start-chrome.sh"
  ok=1
fi

echo "2) 检查 Node / @playwright/mcp ..."
if command -v npx >/dev/null 2>&1; then
  if npx -y @playwright/mcp@latest --version >/dev/null 2>&1; then
    echo "   ✅ @playwright/mcp 可用：$(npx -y @playwright/mcp@latest --version 2>/dev/null)"
  else
    echo "   ❌ @playwright/mcp 拉取失败，检查网络/npm 源"; ok=1
  fi
else
  echo "   ❌ 没有 npx，请先安装 Node.js (https://nodejs.org)"; ok=1
fi

echo ""
[ $ok -eq 0 ] && echo "🎉 全部就绪。去 Codex 里让它：用 chrome 打开 https://example.com 并截图。" || echo "⚠️ 有未通过项，按上面提示修复后重跑：bash verify.sh"
exit $ok
