# 自检（Windows）：确认「Chrome 调试端口」和「@playwright/mcp」都就绪。两项都 ✅ 即可在客户端里使用。
# 用法：powershell -ExecutionPolicy Bypass -File .\verify.ps1

$Port   = if ($env:CHROME_MCP_PORT)    { $env:CHROME_MCP_PORT }    else { "9222" }
$McpVer = if ($env:CHROME_MCP_VERSION) { $env:CHROME_MCP_VERSION } else { "0.0.76" }
$McpPkg = "@playwright/mcp@$McpVer"
$ok = 0

Write-Host "1) 检查 Chrome 远程调试端口 $Port ..."
$Body = $null
try {
  $req = [System.Net.WebRequest]::Create("http://127.0.0.1:$Port/json/version")
  $req.Proxy = $null
  $req.Timeout = 3000
  $res = $req.GetResponse()
  $Body = (New-Object System.IO.StreamReader($res.GetResponseStream())).ReadToEnd()
  $res.Close()
} catch { }
if ($Body -match '"Browser"') {
  Write-Host "   ✅ 在线：$(($Body | ConvertFrom-Json).Browser)"
  if ($Body -match 'webSocketDebuggerUrl') { Write-Host "   ✅ CDP WebSocket 可用（Playwright 就是连这个）" }
} else {
  Write-Host "   ❌ 连不上。请先运行：powershell -ExecutionPolicy Bypass -File .\scripts\start-chrome.ps1"
  $ok = 1
}

Write-Host "2) 检查 Node / $McpPkg ...（首次运行会下载包，可能需要 1-3 分钟）"
if (Get-Command npx -ErrorAction SilentlyContinue) {
  $v = cmd /c "npx -y $McpPkg --version 2>nul"
  if ($LASTEXITCODE -eq 0 -and $v) {
    Write-Host "   ✅ $McpPkg 可用：$v"
  } else {
    Write-Host "   ❌ $McpPkg 拉取失败。国内网络建议先切镜像再重跑："
    Write-Host "      npm config set registry https://registry.npmmirror.com"
    $ok = 1
  }
} else {
  Write-Host "   ❌ 没有 npx，请先安装 Node.js (https://nodejs.org)"; $ok = 1
}

Write-Host ""
if ($ok -eq 0) { Write-Host "🎉 全部就绪。重启客户端会话后试试：用 chrome 打开 https://example.com 并截图。" }
else { Write-Host "⚠️ 有未通过项，按上面提示修复后重跑 verify.ps1" }
exit $ok
