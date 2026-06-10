# 启动带远程调试 + 独立持久 profile 的 Chrome（Windows）。在窗口里登录一次，登录态长期保存。
# 用法：powershell -ExecutionPolicy Bypass -File .\scripts\start-chrome.ps1
# 换端口：$env:CHROME_MCP_PORT=9333 后重跑；自定义 Chrome 路径：$env:CHROME_BIN

$Port       = if ($env:CHROME_MCP_PORT)    { $env:CHROME_MCP_PORT }    else { "9222" }
$ProfileDir = if ($env:CHROME_MCP_PROFILE) { $env:CHROME_MCP_PROFILE } else { "$env:USERPROFILE\.chrome-mcp-profile" }

# 探测 CDP 端口上是否已有调试版 Chrome（绕过系统代理直连 127.0.0.1）
function Test-Cdp([string]$P) {
  try {
    $req = [System.Net.WebRequest]::Create("http://127.0.0.1:$P/json/version")
    $req.Proxy = $null
    $req.Timeout = 3000
    $res = $req.GetResponse()
    $body = (New-Object System.IO.StreamReader($res.GetResponseStream())).ReadToEnd()
    $res.Close()
    return ($body -match '"Browser"')
  } catch { return $false }
}

# 端口占用检查（区分「自己之前启的调试 Chrome」和「别的程序」）
if (Test-Cdp $Port) {
  Write-Host "✅ 端口 $Port 上已有一个调试版 Chrome 在运行，直接复用即可，无需重启。"
  Write-Host "   如需换端口：`$env:CHROME_MCP_PORT=9333 后重跑本脚本"
  exit 0
}
$Listener = $null
try {
  $Conn = Get-NetTCPConnection -LocalPort ([int]$Port) -State Listen -ErrorAction Stop | Select-Object -First 1
  if ($Conn) { $Listener = (Get-Process -Id $Conn.OwningProcess -ErrorAction SilentlyContinue).ProcessName + " (PID $($Conn.OwningProcess))" }
} catch { }
if ($Listener) {
  Write-Host "❌ 端口 $Port 被别的程序占用（$Listener），不是调试版 Chrome。"
  Write-Host "   换一个端口：`$env:CHROME_MCP_PORT=9333 后重跑（记得 MCP 配置里的 --cdp-endpoint 也改成同一端口）"
  exit 1
}

# 探测 Chrome 路径
$Candidates = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$Chrome = if ($env:CHROME_BIN) { $env:CHROME_BIN } else { $Candidates | Where-Object { Test-Path $_ } | Select-Object -First 1 }
if (-not $Chrome) { Write-Host "❌ 找不到 Chrome，请用 `$env:CHROME_BIN 指定 chrome.exe 路径"; exit 1 }

New-Item -ItemType Directory -Force -Path $ProfileDir | Out-Null

Write-Host "🚀 启动调试版 Chrome  CDP端口=$Port  profile=$ProfileDir"
Start-Process -FilePath $Chrome -ArgumentList @(
  "--remote-debugging-port=$Port",
  "--user-data-dir=$ProfileDir",
  "--no-first-run", "--no-default-browser-check", "about:blank"
)

# 等 CDP 真正起来（最多 ~15s），起来了再返回，方便 agent 顺序往下走
for ($i = 0; $i -lt 30; $i++) {
  if (Test-Cdp $Port) {
    Write-Host "✅ 已启动并就绪（CDP 端口 $Port，后台运行，关终端不死）。"
    Write-Host "   ➜ 现在请在弹出的 Chrome 窗口里【登录一次】你要自动化的网站，登录态会长期保存。"
    Write-Host "   ➜ 配置完成后保持它开着。验证：powershell -ExecutionPolicy Bypass -File .\verify.ps1"
    exit 0
  }
  Start-Sleep -Milliseconds 500
}
Write-Host "⚠️ Chrome 已启动，但端口 $Port 15s 内未就绪。常见原因：系统/公司代理拦了本地连接，或端口被占。"
Write-Host "   换端口重试：`$env:CHROME_MCP_PORT=9333 后重跑本脚本"
exit 0
