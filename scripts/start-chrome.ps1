# 启动带远程调试 + 独立持久 profile 的 Chrome（Windows）。在窗口里登录一次，登录态长期保存。
# 用法：powershell -ExecutionPolicy Bypass -File .\scripts\start-chrome.ps1

$Port    = if ($env:CHROME_MCP_PORT)    { $env:CHROME_MCP_PORT }    else { "9222" }
$Profile = if ($env:CHROME_MCP_PROFILE) { $env:CHROME_MCP_PROFILE } else { "$env:USERPROFILE\.chrome-mcp-profile" }

# 探测 Chrome 路径
$Candidates = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$Chrome = if ($env:CHROME_BIN) { $env:CHROME_BIN } else { $Candidates | Where-Object { Test-Path $_ } | Select-Object -First 1 }
if (-not $Chrome) { Write-Host "❌ 找不到 Chrome，请用 `$env:CHROME_BIN 指定 chrome.exe 路径"; exit 1 }

New-Item -ItemType Directory -Force -Path $Profile | Out-Null

Write-Host "🚀 启动调试版 Chrome  CDP端口=$Port  profile=$Profile"
Write-Host "   ➜ 在弹出的窗口里登录你要自动化的网站，登录态会长期保存。保持窗口开着。"
& $Chrome "--remote-debugging-port=$Port" "--user-data-dir=$Profile" "--no-first-run" "--no-default-browser-check" "about:blank"
