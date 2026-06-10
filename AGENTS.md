# AGENTS.md — 给「负责安装本服务的 AI agent」的指令

你（Codex / Claude Code / Cursor 等）正在帮用户安装 **agent-chrome-mcp**：让一个名为 `chrome` 的 MCP 工具，通过 CDP 连接用户**带登录态的真实 Chrome**，从而能打开网页、点击、填表、抓取、截图。

按下面顺序执行。**机器能做的步骤（0-5）全部自动完成，「登录」是唯一交还给真人的一步，放在最后。**

---

## ⛔ 不可代办的一步：登录（必须交还给真人，放在所有配置完成之后）

- `start-chrome` 脚本打开的 Chrome 是**未登录**的。
- 你**没有、也不应索取**用户的淘宝 / 小红书 / 后台等账号密码。
- **不要**尝试自动填账号密码、自动点登录、绕过验证码或读取用户凭据。这一步天然属于人。
- 配置全部完成后（第 6 步），对用户说：
  > 「全部配置已完成 ✅。最后一步需要你本人：在弹出的 Chrome 窗口里**登录一次**你要自动化的网站（只需登录一次，登录态会长期保存）。登录好后告诉我，我帮你做一次实测。」

---

## 你可以自动完成的步骤

### 0. 判断环境
先确认两件事，后面按此选择命令：
- **操作系统**：macOS / Windows / Linux
- **你自己是哪个客户端**：Codex / Claude Code / Cursor / 其他（第 4 步要把 MCP 配进「你所在的那个客户端」）

### 1. 前置检查
```bash
node -v && npx -v        # 需要 Node 18+；没有则引导用户去 https://nodejs.org 装 LTS
```
检查 Chrome（按操作系统选一条）：
```bash
# macOS
ls "/Applications/Google Chrome.app" >/dev/null 2>&1 && echo OK || echo "需要安装 Google Chrome"
# Linux
command -v google-chrome || command -v google-chrome-stable || command -v chromium || echo "需要安装 Google Chrome"
```
```powershell
# Windows (PowerShell)
if (Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe") { "OK" } else { "需要安装 Google Chrome" }
```

### 2. 预热 @playwright/mcp（关键，防首启超时）
```bash
npx -y @playwright/mcp@0.0.76 --version
```
- 首次运行会下载包，可能要 1-3 分钟，耐心等它结束。**这一步先把包缓存好，客户端启动 MCP 时就不用现场下载，否则极易超时失败。**
- 若下载很慢或失败（国内网络常见），先切 npm 镜像再重试：
  ```bash
  npm config set registry https://registry.npmmirror.com
  ```

### 3. 启动专用调试 Chrome（脚本会脱离终端启动并等端口就绪后返回）
```bash
bash scripts/start-chrome.sh                                          # macOS / Linux
```
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-chrome.ps1   # Windows
```
- 默认 CDP 端口 `9222`、持久 profile `~/.chrome-mcp-profile`。
- 若端口被「别的程序」占用，脚本会报错并提示换端口：`CHROME_MCP_PORT=9333`（记得第 4 步的 `--cdp-endpoint` 端口同步改）。
- 若端口上已有「本包之前启动的调试 Chrome」，脚本会直接复用并正常返回，不算失败。

### 4. 把 `chrome` MCP 加进【你自己所在的客户端】

- **Codex**（两条都要做）：
  ```bash
  codex mcp add chrome \
    --env NO_PROXY=127.0.0.1,localhost,::1 --env no_proxy=127.0.0.1,localhost,::1 \
    -- npx -y @playwright/mcp@0.0.76 --cdp-endpoint http://127.0.0.1:9222 --browser chrome
  ```
  然后**必须**检查 `~/.codex/config.toml`：`codex mcp add` 不会写启动超时，你要亲自在 `[mcp_servers.chrome]` 段下补一行（已存在则跳过）：
  ```toml
  startup_timeout_sec = 120
  ```
  （Codex 默认超时很短，npx 启动稍慢就会判死 MCP——这是过去客户安装失败的头号原因。）

- **Claude Code**：
  ```bash
  claude mcp add chrome -s user \
    -e NO_PROXY=127.0.0.1,localhost,::1 -e no_proxy=127.0.0.1,localhost,::1 \
    -- npx -y @playwright/mcp@0.0.76 --cdp-endpoint http://127.0.0.1:9222 --browser chrome
  ```

- **Cursor**：把下面合并进 `~/.cursor/mcp.json`（文件不存在就创建；已有 `mcpServers` 就只加 `chrome` 这个 key）：
  ```json
  {
    "mcpServers": {
      "chrome": {
        "command": "npx",
        "args": ["-y", "@playwright/mcp@0.0.76", "--cdp-endpoint", "http://127.0.0.1:9222", "--browser", "chrome"],
        "env": { "NO_PROXY": "127.0.0.1,localhost,::1", "no_proxy": "127.0.0.1,localhost,::1" }
      }
    }
  }
  ```

- **其他客户端**：参考 `codex-config-snippet.toml` 的 `command` / `args` / `env`，语义一致。

> **Windows 注意**：如果客户端报「找不到 npx / spawn npx ENOENT」，把 `command` 换成 `cmd`，并在 `args` 最前面加 `"/c", "npx"`。

### 5. 验证
```bash
bash verify.sh                                                  # macOS / Linux
```
```powershell
powershell -ExecutionPolicy Bypass -File .\verify.ps1           # Windows
```
两项均 ✅ 即配置成功。

### 6. 交还给用户登录（见顶部 ⛔），并提醒两件事
1. **重启客户端会话**后 `chrome` 工具才会出现（Codex 开新会话；Claude Code 重启或 `/mcp` 检查；Cursor 在 MCP 设置里启用）。
2. 用户登录完成后，做一次实测：调用 `chrome` 工具 `browser_navigate` 打开用户已登录的站点，确认能看到登录态。

---

## 验证「真的好了」的标准
- `verify.sh` / `verify.ps1` 两项都 ✅；
- 重启会话后客户端里能看到 `chrome` 工具；
- 通过 `chrome` 工具能 `navigate` 到一个用户**已登录**的站点并看到登录态（由用户登录后才成立）。

## 排错（按顺序先查这些）
1. **客户端里 `chrome` 工具不出现 / 启动失败**：十有八九是 npx 首启下载超时。先跑第 2 步预热；Codex 用户确认 `startup_timeout_sec = 120` 已写入 config.toml；然后重启客户端会话。
2. **报 "retrieving websocket url … timeout" / Chrome 开着却连不上**：几乎都是**系统/公司代理拦了到 127.0.0.1 的连接**。确认 MCP 配置的 `env` 里有 `NO_PROXY=127.0.0.1,localhost,::1`（本包默认已加）。
3. **端口被占**：`CHROME_MCP_PORT=9333` 重启脚本，并把 `--cdp-endpoint` 端口同步改。
4. **连不上**：确认第 3 步的 Chrome 还在运行（它必须保持开着）。
5. **npm 下载失败/极慢**：`npm config set registry https://registry.npmmirror.com` 后重试。

## 模式
- **默认（A）**：上述流程，CDP 连专用持久 Chrome。
- **备选（B）**：接管用户**日常 Chrome**（已有全部登录）→ 用 `--extension`（需用户安装 Playwright 浏览器扩展），细节见 `README.md`。

> 安全：本包不含任何密钥；不要把用户凭据写进任何文件或配置。
