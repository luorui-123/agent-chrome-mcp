# agent-chrome-mcp

> Give any MCP client (**Codex / Claude / Cursor**) control of your **real, logged-in Chrome** via CDP — no extra login, no headless throwaway browser. · License: **MIT**

让 **Codex / Claude / Cursor 等 MCP 客户端** 通过 MCP **直连你带登录态的真实 Chrome**，完成浏览器自动化：打开网页、点击、填表、抓取、截图、读页面结构……
登录一次（淘宝 / 小红书 / 后台系统等），登录态长期保存，之后 AI 直接在你已登录的浏览器里干活。

> 下面的安装步骤以 **Codex** 为例；Claude Code / Cursor 等任意 MCP 客户端同理（把同样的 `command`/`args` 填进它们的 MCP 配置即可）。

> 本包**不依赖任何第三方平台**，核心是官方维护的 [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp)。给客户即装即用。

---

## 0. 它能做什么

在 Codex 里你可以直接说：
- “用 chrome 打开后台，把今天的订单导出截图给我”
- “在小红书搜‘保温杯’，把前 10 条笔记标题和点赞抓下来”
- “登录态已经有了，帮我在淘宝后台改这个商品的标题”

Codex 会调用 `chrome` 这个 MCP 工具，在你**已登录的真实 Chrome**里执行。

---

## 1. 前置要求（客户机器需要）

| 必需 | 说明 |
|---|---|
| **Node.js 18+** | 提供 `npx`。装 → https://nodejs.org |
| **Google Chrome** | 普通版即可 |
| **Codex CLI** | `codex --version`，需 0.13+（支持 `codex mcp`） |

---

## 2. 三步安装

### 第 1 步：启动「专用调试 Chrome」并登录

```bash
bash scripts/start-chrome.sh        # macOS / Linux
# Windows: powershell -ExecutionPolicy Bypass -File .\scripts\start-chrome.ps1
```

会弹出一个 Chrome 窗口（独立 profile，CDP 端口 9222）。
**在这个窗口里登录你要自动化的网站**（淘宝、小红书、各种后台……）。
登录态保存在 `~/.chrome-mcp-profile`，以后不用重登。**保持这个窗口开着。**

> 想换端口：`CHROME_MCP_PORT=9333 bash scripts/start-chrome.sh`（记得第 2 步的端口也同步改）。
> Chrome 路径不标准：`CHROME_BIN="/path/to/chrome" bash scripts/start-chrome.sh`。

### 第 2 步：把 Chrome MCP 加进 Codex

**方式一（推荐，一行命令）：**
```bash
codex mcp add chrome \
  --env NO_PROXY=127.0.0.1,localhost,::1 --env no_proxy=127.0.0.1,localhost,::1 \
  -- npx -y @playwright/mcp@latest --cdp-endpoint http://127.0.0.1:9222 --browser chrome
```
（`NO_PROXY` 是防止系统/公司代理拦截到本地 Chrome 的连接，无代理时也无害。）

**方式二（手动）：** 打开 `codex-config-snippet.toml`，把里面的片段粘到 `~/.codex/config.toml` 末尾。

确认已加上：
```bash
codex mcp list      # 应能看到 chrome
```

### 第 3 步：自检

```bash
bash verify.sh
```
两项都 ✅ 就绪。

### 第 4 步：在 Codex 里试

```
用 chrome 打开 https://example.com，截个图给我
```
Codex 应能在你那个 Chrome 窗口里打开页面并返回截图/页面结构。

---

## 3. 两种连接模式

| 模式 | 连的是 | 怎么开 | 适用 |
|---|---|---|---|
| **A（默认）专用持久 Chrome** | 第 1 步启动的那个调试 Chrome | `--cdp-endpoint http://127.0.0.1:9222` | 稳定、可脚本化、登录态独立隔离。**推荐。** |
| **B 接管日常 Chrome** | 你平时正在用的 Chrome（所有现成登录） | `--extension`（需装 Playwright 浏览器扩展） | 想直接用日常浏览器、不想另开窗口 |

切到模式 B：见 `codex-config-snippet.toml` 里被注释的那段；并按 Playwright 提示安装其浏览器扩展。

---

## 4. 常见问题

- **`verify.sh` 第 1 项失败 / 连不上 9222**：第 1 步的 Chrome 没开，或被关了。重跑 `start-chrome.sh`。
- **端口被占**：换端口（`CHROME_MCP_PORT=9333`），第 1、2 步端口要一致。
- **Codex 里 chrome 工具不出现**：`codex mcp list` 看有没有；没有就重做第 2 步；重启 Codex 会话。
- **报 “retrieving websocket url … timeout” / 连不上但 Chrome 明明开着**：多半是**系统/公司代理**把到 `127.0.0.1` 的连接也代理了。本包已默认在配置里加了 `NO_PROXY`；若仍不行，确认 `~/.codex/config.toml` 里 `[mcp_servers.chrome.env]` 有 `NO_PROXY=127.0.0.1,localhost,::1`。
- **登录态丢了**：只要还用同一个 `--user-data-dir`（默认 `~/.chrome-mcp-profile`）就不会丢。别删这个目录。
- **抓取/自动化要遵守目标网站条款**：本包只提供能力，怎么用由使用者负责。

---

## 5. 卸载

```bash
codex mcp remove chrome
rm -rf ~/.chrome-mcp-profile      # 如需清除登录态
```

---

## 6. 这个包里有什么

```
chrome-mcp-pack/
├── README.md                  # 本文件
├── scripts/start-chrome.sh    # 启动专用调试 Chrome（macOS/Linux）
├── scripts/start-chrome.ps1   # 同上（Windows）
├── codex-config-snippet.toml  # 粘进 ~/.codex/config.toml 的 MCP 配置
└── verify.sh                  # 安装自检
```

> 可自由改名/换 logo 作为你的产品分发。MCP server 名（`chrome`）也可改，记得三处保持一致：`codex mcp add 名字`、config.toml 的 `[mcp_servers.名字]`、以及对客户的话术。
