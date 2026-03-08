# Installation

本指南用于把本仓库提供的 reboot-otp 资产安装到一个**已有 Picoclaw 部署**中。

完成后，目标命令格式为：

```text
/reboot --otp 123456
```

Picoclaw 会把这个请求导向本地 MCP server。MCP server 在本机校验 TOTP，校验通过后才执行：

- `sudo /usr/sbin/reboot`

本指南故意只覆盖这个窄用例，不安装通用提权执行器。

---

## 1. 推荐路径：引导式安装

推荐先使用仓库根目录的半交互式安装脚本：

```bash
bash ./scripts/install-reboot-otp.sh
```

这个脚本不是黑盒一键部署。它会：

- 先做前置检查
- 收集操作员输入
- 展示计算后的部署值和配置预览
- 在写入前逐步确认
- 对 sudoers 保持显式人工步骤

如果你需要完整人工控制，也可以直接跳到本文后半部分的“手动安装”。

---

## 2. 引导式安装会执行哪些阶段

### 2.1 Preflight checks

安装脚本会先确认：

- 当前系统是 Linux
- 存在 `systemctl`
- 存在 `sudo`
- 存在 `go`
- 主机上存在精确路径 `/usr/sbin/reboot`
- 仓库中的 `mcp-server/`、`skills/reboot-guard/SKILL.md`、`examples/` 资产存在
- `GOTOOLCHAIN=go1.25.7` 可用
- 目标项目路径稍后可被确认
- Picoclaw 配置预期路径为 `~/.picoclaw/config.json`

如果主机上的 reboot 不在 `/usr/sbin/reboot`，脚本会直接失败并提示，不会猜测其他路径。

### 2.2 Collect operator inputs

脚本会询问：

- target project path
- runtime username
- runtime home directory
- installed binary path
  - 默认：`/usr/local/bin/picoclaw-privileged-mcp`
- secret env file path
  - 默认：`~/.picoclaw/secrets/privileged.env`
- action mode
  - `harmless`
  - `real`
- TOTP secret 处理方式
  - 使用现有 secret
  - 生成新的 secret

其中：

- `harmless` 用于先验证成功链路但不真实重启
- `real` 表示正确 OTP 最终会执行 `sudo /usr/sbin/reboot`

### 2.3 Render deployment values

在任何写入之前，脚本会展示：

- target project 路径
- 目标 skill 安装路径
- binary 安装路径
- Picoclaw config 路径
- env 文件路径
- action mode
- 推荐 MCP config snippet
- env 文件预览
- 推荐 sudoers line

然后要求你明确确认，才继续执行。

### 2.4 Build and install the MCP binary

脚本会从：

- `mcp-server/`

使用：

- `GOTOOLCHAIN=go1.25.7`

构建 binary，并安装到你确认过的绝对路径。

默认安装路径：

- `/usr/local/bin/picoclaw-privileged-mcp`

### 2.5 Install the skill into the target project

脚本会把：

- `skills/reboot-guard/SKILL.md`

复制到：

- `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`

### 2.6 Create or render config artifacts

脚本对配置文件采取保守策略：

- 如果 secret env 文件需要写入，会再次确认
- 如果 `~/.picoclaw/config.json` **不存在**，脚本可以在确认后写入一个新的最小配置文件
- 如果 `~/.picoclaw/config.json` **已存在**，脚本不会盲目 patch，而是打印 ready-to-merge JSON snippet 供你手动合并

这样做是为了避免脆弱 JSON patch 破坏已有配置。

### 2.7 Handle sudoers safely

脚本**不会**静默修改 sudoers。

它只会打印：

- 精确推荐 sudoers line
- 建议文件路径：`/etc/sudoers.d/picoclaw`
- 可选 helper command，供你人工审核后执行

推荐规则仍然只有一行：

```sudoers
YOUR_USER ALL=(root) NOPASSWD: /usr/sbin/reboot
```

不会扩展成 `ALL`、shell、通配符或其他提权动作。

### 2.8 Print final next steps

脚本最后会打印：

- 重启 Picoclaw 的提醒
- 测 malformed input
- 测 invalid OTP
- 测 missing `TOTP_SECRET`
- 先做 harmless success path
- 只有准备好后再做 real reboot path

详细验证项见：

- [`testing.md`](./testing.md)

---

## 3. 引导式安装后的默认部署路径

默认情况下，脚本围绕以下路径工作：

- binary：
  - `/usr/local/bin/picoclaw-privileged-mcp`
- Picoclaw config：
  - `~/.picoclaw/config.json`
- secret env：
  - `~/.picoclaw/secrets/privileged.env`
- skill：
  - `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`

同时实现仍保持：

- 固定 reboot 路径：`/usr/sbin/reboot`

---

## 4. 手动安装（fallback）

如果你不想运行安装脚本，也可以手动完成整个部署。

### 4.1 准备 TOTP secret

你需要准备一个 TOTP secret，并同时保存到：

- 手机认证器 App
- 本地主机环境变量来源

注意：

- 不要把 secret 提交进 git
- 不要把 secret 发进聊天
- 不要把示例 secret 当成真实 secret

### 4.2 构建 Go MCP server

从本仓库源码目录构建 MCP server：

```bash
cd "PROJECT_ROOT/mcp-server"
GOTOOLCHAIN=go1.25.7 go mod tidy
GOTOOLCHAIN=go1.25.7 go build -o picoclaw-privileged-mcp
```

### 4.3 安装 MCP binary

把 binary 安装到稳定绝对路径：

- `/usr/local/bin/picoclaw-privileged-mcp`

### 4.4 创建 secret env 文件

创建：

- `~/.picoclaw/secrets/privileged.env`

推荐示例：

- [`../examples/privileged.env.example`](../examples/privileged.env.example)

推荐权限：

- 目录：`700`
- 文件：`600`

### 4.5 配置 Picoclaw MCP

编辑：

- `~/.picoclaw/config.json`

参考：

- [`../examples/picoclaw-config.example.json`](../examples/picoclaw-config.example.json)
- [`configuration.md`](./configuration.md)

### 4.6 安装本地 skill

把：

- `skills/reboot-guard/SKILL.md`

复制到：

- `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`

### 4.7 添加 sudoers 规则

参考：

- [`../examples/sudoers.example`](../examples/sudoers.example)
- [`sudoers.md`](./sudoers.md)

推荐规则仍然只有：

```sudoers
YOUR_USER ALL=(root) NOPASSWD: /usr/sbin/reboot
```

### 4.8 重启 Picoclaw

让 Picoclaw 重新加载：

- MCP 配置
- env_file
- 安装后的 binary
- 目标项目中的 skill

### 4.9 做安全验证

按顺序验证：

1. malformed input
2. invalid OTP
3. missing `TOTP_SECRET`
4. harmless success path
5. real reboot path

详见：

- [`testing.md`](./testing.md)

---

## 5. 预期命令格式

唯一支持的命令格式是：

```text
/reboot --otp 123456
```

v1 故意**不支持**：

- `/reboot`
- 额外 reboot flags
- 自然语言 reboot 请求
- 任意高权限命令
- 通用 sudo 替代行为

保持输入格式窄，有助于降低歧义并保持边界清晰。

---

## 6. 成功与失败的典型表现

### 格式错误

```text
Usage: /reboot --otp 123456
```

### OTP 错误

```text
OTP verification failed. Reboot request denied.
```

### OTP 未配置

```text
OTP verification is not configured.
```

### Harmless 成功

```text
OTP verified. Reboot test command executed.
```

### Real reboot 成功

```text
OTP verified. System is rebooting.
```

重要：

- 不应回显 OTP
- 不应在日志中打印 OTP

---

## 7. 卸载 / 回滚

如果要移除这套能力，建议按以下顺序回滚：

1. 删除目标项目里的 skill
2. 从 `~/.picoclaw/config.json` 移除 MCP server 配置
3. 删除安装好的 MCP binary
4. 删除 secret env 文件
5. 删除 sudoers 规则
6. 重启 Picoclaw

回滚完成后请确认：

- Picoclaw 正常启动
- MCP tool 不再注册
- `/reboot --otp 123456` 不再触发这套自定义流程

---

## 8. 后续建议阅读

- [`configuration.md`](./configuration.md)
- [`sudoers.md`](./sudoers.md)
- [`security.md`](./security.md)
- [`troubleshooting.md`](./troubleshooting.md)
- [`development.md`](./development.md)
- [`testing.md`](./testing.md)
