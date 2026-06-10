# agent-chrome-mcp

> Give any MCP client (**Codex / Claude / Cursor**) control of your **real, logged-in Chrome** via CDP — no extra login, no headless throwaway browser. · License: **MIT**

让 **Codex / Claude / Cursor 等 MCP 客户端** 通过 MCP **直连你带登录态的真实 Chrome**，完成浏览器自动化：打开网页、点击、填表、抓取、截图、读页面结构……
登录一次（淘宝 / 小红书 / 后台系统等），登录态长期保存，之后 AI 直接在你已登录的浏览器里干活。

> 🤖 **推荐安装方式：让 AI agent 帮你装。** 克隆本仓库后，在仓库目录里打开你的 Codex / Claude Code / Cursor，说一句：
> **「按这个仓库的说明，把 Chrome MCP 装好」**
> 它会读 [`AGENTS.md`](AGENTS.md) 自动完成全部配置。**唯一需要你本人做的是「登录一次」**——agent 不会、也不该碰你的账号密码，配置完成后它会请你登录。
>
> 本包**不依赖任何第三方平台**，核心是官方维护的 [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp)（版本已钉死在 `0.0.76`，保证可复现、启动快）。

---

## 0. 它能做什么

装好后你可以直接对 AI 说：
- "用 chrome 打开后台，把今天的订单导出截图给我"
- "在小红书搜'保温杯'，把前 10 条笔记标题和点赞抓下来"
- "登录态已经有了，帮我在淘宝后台改这个商品的标题"

AI 会调用 `chrome` 这个 MCP 工具，在你**已登录的真实 Chrome**里执行。

---

## 1. 前置要求（客户机器需要）

| 必需 | 说明 |
|---|---|
| **Node.js 18+** | 提供 `npx`。装 → https://nodejs.org |
| **Google Chrome** | 普通版即可 |
| **任一 MCP 客户端** | Codex CLI ≥0.13 / Claude Code / Cursor |

---

## 2. 手动安装（四步）

> 让 agent 装的话跳过本节——它会按 `AGENTS.md` 自己做完这些。

### 第 1 步：启动「专用调试 Chrome」并登录

```bash
bash scripts/start-chrome.sh        # macOS / Linux
```
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-chrome.ps1   # Windows
```

会弹出一个 Chrome 窗口（独立 profile，CDP 端口 9222）。
**在这个窗口里登录你要自动化的网站**（淘宝、小红书、各种后台……）。
登录态保存在 `~/.chrome-mcp-profile`，以后不用重登。**保持这个窗口开着。**

> 想换端口：`CHROME_MCP_PORT=9333 bash scripts/start-chrome.sh`（记得后面步骤的端口也同步改）。
> Chrome 路径不标准：`CHROME_BIN="/path/to/chrome" bash scripts/start-chrome.sh`。

### 第 2 步：把 Chrome MCP 加进你的客户端

**Codex（两条都要做）：**
```bash
codex mcp add chrome \
  --env NO_PROXY=127.0.0.1,localhost,::1 --env no_proxy=127.0.0.1,localhost,::1 \
  -- npx -y @playwright/mcp@0.0.76 --cdp-endpoint http://127.0.0.1:9222 --browser chrome
```
然后打开 `~/.codex/config.toml`，在 `[mcp_servers.chrome]` 段下**手动补一行**（`codex mcp add` 写不了这个字段，但它很关键——Codex 默认启动超时很短，npx 稍慢 MCP 就被判死）：
```toml
startup_timeout_sec = 120
```
（或者不用命令，直接把 `codex-config-snippet.toml` 整段粘到 `~/.codex/config.toml` 末尾，超时已含。）
确认：`codex mcp list` 应能看到 chrome。

**Claude Code（一条命令）：**
```bash
claude mcp add chrome -s user \
  -e NO_PROXY=127.0.0.1,localhost,::1 -e no_proxy=127.0.0.1,localhost,::1 \
  -- npx -y @playwright/mcp@0.0.76 --cdp-endpoint http://127.0.0.1:9222 --browser chrome
```
确认：`claude mcp list` 应能看到 chrome。

**Cursor：** 把下面合并进 `~/.cursor/mcp.json`（没有就新建）：
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

（`NO_PROXY` 是防止系统/公司代理拦截到本地 Chrome 的连接，无代理时也无害。）

### 第 3 步：自检（兼任「预热」，必跑）

```bash
bash verify.sh                                          # macOS / Linux
```
```powershell
powershell -ExecutionPolicy Bypass -File .\verify.ps1   # Windows
```

前两项都 ✅ 就绪。**首次运行会下载 @playwright/mcp（可能 1-3 分钟），这是故意的**——先把包缓存好，客户端启动 MCP 时就不用现场下载，否则极易超时。

### 第 4 步：重启客户端会话，试一把

**新开一个会话**（MCP 配置在新会话才生效），然后说：

```
用 chrome 打开 https://example.com，截个图给我
```

AI 应能在你那个 Chrome 窗口里打开页面并返回截图/页面结构。

---

## 3. 两种连接模式

| 模式 | 连的是 | 怎么开 | 适用 |
|---|---|---|---|
| **A（默认）专用持久 Chrome** | 第 1 步启动的那个调试 Chrome | `--cdp-endpoint http://127.0.0.1:9222` | 稳定、可脚本化、登录态独立隔离。**推荐。** |
| **B 接管日常 Chrome** | 你平时正在用的 Chrome（所有现成登录） | `--extension`（需装 Playwright 浏览器扩展） | 想直接用日常浏览器、不想另开窗口 |

切到模式 B：见 `codex-config-snippet.toml` 里被注释的那段；并按 Playwright 提示安装其浏览器扩展。

---

## 4. 常见问题

- **客户端里 chrome 工具不出现 / MCP 启动失败**：十有八九是 npx 首次启动要现场下载包、超时被判死。跑一遍 `verify.sh`（预热缓存），Codex 用户确认 `~/.codex/config.toml` 里有 `startup_timeout_sec = 120`，然后**新开会话**再试。
- **下载 @playwright/mcp 很慢/失败（国内常见）**：先切 npm 镜像：`npm config set registry https://registry.npmmirror.com`，再重跑 `verify.sh`。
- **`verify` 第 1 项失败 / 连不上 9222**：第 1 步的 Chrome 没开，或被关了。重跑 `start-chrome` 脚本。
- **端口被占**：换端口（`CHROME_MCP_PORT=9333`），所有步骤的端口要一致。
- **报 "retrieving websocket url … timeout" / 连不上但 Chrome 明明开着**：多半是**系统/公司代理**把到 `127.0.0.1` 的连接也代理了。本包已默认在配置里加了 `NO_PROXY`；若仍不行，确认你客户端 MCP 配置的 `env` 里有 `NO_PROXY=127.0.0.1,localhost,::1`。
- **Windows 报「找不到 npx / spawn npx ENOENT」**：把 MCP 配置里的 `command` 换成 `cmd`，`args` 最前面加 `"/c", "npx"`。
- **登录态丢了**：只要还用同一个 `--user-data-dir`（默认 `~/.chrome-mcp-profile`）就不会丢。别删这个目录。
- **抓取/自动化要遵守目标网站条款**：本包只提供能力，怎么用由使用者负责。

---

## 5. 卸载

```bash
codex mcp remove chrome           # Codex
claude mcp remove chrome -s user  # Claude Code
# Cursor：删掉 ~/.cursor/mcp.json 里的 "chrome" 段
rm -rf ~/.chrome-mcp-profile      # 如需清除登录态
```

---

## 6. 这个包里有什么

```
agent-chrome-mcp/
├── README.md                  # 本文件（给人看的安装说明）
├── AGENTS.md                  # 给 AI agent 看的自动安装指令
├── CLAUDE.md                  # Claude Code 入口（指向 AGENTS.md）
├── scripts/start-chrome.sh    # 启动专用调试 Chrome（macOS/Linux）
├── scripts/start-chrome.ps1   # 同上（Windows）
├── codex-config-snippet.toml  # 粘进 ~/.codex/config.toml 的 MCP 配置
├── verify.sh                  # 安装自检 + 预热（macOS/Linux）
└── verify.ps1                 # 同上（Windows）
```

> **维护备注**：`@playwright/mcp` 版本钉死在 `0.0.76`（钉死 = 启动不查 npm registry，快且离线可用）。要升级版本时，全局搜索替换 `0.0.76`，涉及：README.md、AGENTS.md、codex-config-snippet.toml、verify.sh、verify.ps1。
>
> 可自由改名/换 logo 作为你的产品分发。MCP server 名（`chrome`）也可改，记得在注册命令、配置文件和对客户的话术里保持一致。
