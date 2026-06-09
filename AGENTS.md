# AGENTS.md — 给「负责安装本服务的 AI agent」的指令

你(Codex / Claude Code / Cursor 等)正在帮用户安装 **agent-chrome-mcp**:让一个名为 `chrome` 的 MCP 工具,通过 CDP 连接用户**带登录态的真实 Chrome**,从而能打开网页、点击、填表、抓取、截图。

按下面顺序执行。**先读完「不可代办的一步」再动手。**

---

## ⛔ 不可代办的一步:登录(必须交还给真人)

- `scripts/start-chrome.sh` 打开的 Chrome 是**未登录**的。
- 你**没有、也不应索取**用户的淘宝 / 小红书 / 后台等账号密码。
- 因此:在「启动 Chrome」之后、「最终验证」之前,**停下来**,对用户说:
  > 「我已经打开了一个专用 Chrome 窗口。请你在里面**登录一次**你要自动化的网站(只需登录一次,登录态会长期保存)。登录好后告诉我,我继续。」
- **不要**尝试自动填账号密码、自动点登录、绕过验证码或读取用户凭据。这一步天然属于人。

---

## 你可以自动完成的步骤

### 1. 前置检查
```bash
node -v && npx -v        # 需要 Node 18+
ls "/Applications/Google Chrome.app" 2>/dev/null || echo "需要安装 Google Chrome"
```

### 2. 启动专用调试 Chrome(脚本会脱离终端启动并等端口就绪后返回)
```bash
bash scripts/start-chrome.sh
```
- 默认 CDP 端口 `9222`、持久 profile `~/.chrome-mcp-profile`。
- 若端口被占,脚本会提示换端口:`CHROME_MCP_PORT=9333 bash scripts/start-chrome.sh`(记得第 3 步的 `--cdp-endpoint` 端口同步改)。

### → 在这里停下,执行上面「登录」交接,等用户确认登录完成。

### 3. 把 `chrome` MCP 加进【你自己所在的客户端】
- **Codex**:
  ```bash
  codex mcp add chrome \
    --env NO_PROXY=127.0.0.1,localhost,::1 --env no_proxy=127.0.0.1,localhost,::1 \
    -- npx -y @playwright/mcp@latest --cdp-endpoint http://127.0.0.1:9222 --browser chrome
  ```
- **Claude Code / Cursor / 其他**:把等价的 `command` / `args` / `env` 写进它们各自的 MCP 配置(直接参考 `codex-config-snippet.toml` 里的字段,语义一致)。

### 4. 验证
```bash
bash verify.sh
```
两项均 ✅ 即配置成功。随后你可以调用 `chrome` 工具(如 `browser_navigate`)在用户已登录的浏览器里操作。

---

## 验证「真的好了」的标准
- `verify.sh` 两项都 ✅;
- 通过 `chrome` MCP 工具能 `navigate` 到一个用户**已登录**的站点并看到登录态(由用户登录后才成立)。

## 排错(按顺序先查这些)
1. **报 “retrieving websocket url … timeout” / Chrome 开着却连不上**:几乎都是**系统/公司代理拦了到 127.0.0.1 的连接**。确认 MCP 配置的 `env` 里有 `NO_PROXY=127.0.0.1,localhost,::1`(本包默认已加)。
2. **端口被占**:`CHROME_MCP_PORT=9333` 重启脚本,并把 `--cdp-endpoint` 端口同步改。
3. **连不上**:确认第 2 步的 Chrome 还在运行(它必须保持开着)。

## 模式
- **默认(A)**:上述流程,CDP 连专用持久 Chrome。
- **备选(B)**:接管用户**日常 Chrome**(已有全部登录)→ 用 `--extension`(需用户安装 Playwright 浏览器扩展),细节见 `README.md`。

> 安全:本包不含任何密钥;不要把用户凭据写进任何文件或配置。
