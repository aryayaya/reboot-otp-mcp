# Configuration

本文描述 reboot-otp 流程所需的三块核心配置：

1. Picoclaw MCP server 配置
2. 包含 `TOTP_SECRET` 的 secret env 文件
3. 将 `/reboot --otp 123456` 映射到 MCP tool 的本地 skill

本方案故意保持配置范围窄、路径明确。

---

## 1. 需要配置什么

要让这条 reboot 流程真正工作，你至少需要：

- 一个已安装的 MCP binary
- 一条 Picoclaw MCP server 配置
- 一个包含 `TOTP_SECRET` 的 secret env 文件
- 一个安装到目标项目内的本地 skill 文件

整体关系如下：

```text
Telegram / chat input
  -> reboot-guard skill
  -> reboot_system MCP tool
  -> local Go MCP server
  -> TOTP verification
  -> sudo /usr/sbin/reboot
```

其中任何一环路径不对、文件缺失或配置错误，整条链路都会失败。

---

## 2. 配置总览

### 本仓库中的源码路径

- 安装脚本：
  - `scripts/install-reboot-otp.sh`
- Picoclaw config 示例：
  - `examples/picoclaw-config.example.json`
- env 示例：
  - `examples/privileged.env.example`
- sudoers 示例：
  - `examples/sudoers.example`
- skill 源码：
  - `skills/reboot-guard/SKILL.md`
- MCP 源码：
  - `mcp-server/`

### 目标部署路径

- Picoclaw 配置：
  - `~/.picoclaw/config.json`
- secret env 文件：
  - `~/.picoclaw/secrets/privileged.env`
- 安装后的 MCP binary：
  - `/usr/local/bin/picoclaw-privileged-mcp`
- 目标项目内的 skill：
  - `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`

推荐原则：

- secret 不进 git 仓库
- binary 路径稳定且绝对
- skill 放在目标项目里
- 命令输入面尽量窄

---

## 3. 安装脚本可能写哪些文件

引导式安装脚本的默认入口为：

- `scripts/install-reboot-otp.sh`

它遵循“能安全自动化的才写，脆弱或高风险的只打印”的原则。

### 可能由脚本写入

- 安装后的 binary：
  - 默认 `/usr/local/bin/picoclaw-privileged-mcp`
- 目标项目 skill：
  - `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`
- secret env 文件：
  - 默认 `~/.picoclaw/secrets/privileged.env`
  - 仅在你明确确认后写入
- 新的最小 Picoclaw config：
  - `~/.picoclaw/config.json`
  - 仅当该文件当前不存在，且你明确确认后创建

### 只会打印、不会自动写入

- sudoers 规则
- 已存在 `~/.picoclaw/config.json` 时的 MCP JSON 片段

这意味着：

- 脚本不会静默扩大 sudoers 权限
- 脚本不会盲目 patch 复杂 JSON

---

## 4. 安装脚本的默认值

安装脚本默认使用：

- binary path：
  - `/usr/local/bin/picoclaw-privileged-mcp`
- Picoclaw config path：
  - `~/.picoclaw/config.json`
- env file path：
  - `~/.picoclaw/secrets/privileged.env`
- deployed skill path：
  - `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`
- required reboot path：
  - `/usr/sbin/reboot`
- Go toolchain for build：
  - `GOTOOLCHAIN=go1.25.7`
- default action mode：
  - `harmless`

### Action mode

env 文件除了 `TOTP_SECRET` 之外，还会包含：

```env
REBOOT_ACTION_MODE=harmless
```

或：

```env
REBOOT_ACTION_MODE=real
```

其中：

- `harmless`：验证成功路径但不真实 reboot
- `real`：正确 OTP 最终执行 `sudo /usr/sbin/reboot`

任何非 `harmless` 值都会按 real 模式处理，因此建议只使用这两个显式值。

---

## 5. Picoclaw MCP 配置

编辑：

- `~/.picoclaw/config.json`

你需要：

- 全局启用 MCP
- 增加一个 stdio MCP server
- 指向已安装的 binary
- 使用 `env_file` 传入 `TOTP_SECRET`

### 推荐最小示例

完整示例文件：

- `examples/picoclaw-config.example.json`

内容如下：

```json
{
  "mcp": {
    "enabled": true,
    "servers": {
      "privileged": {
        "enabled": true,
        "type": "stdio",
        "command": "/usr/local/bin/picoclaw-privileged-mcp",
        "args": [],
        "env_file": "/home/YOUR_USER/.picoclaw/secrets/privileged.env"
      }
    }
  }
}
```

把：

- `YOUR_USER`

替换成你的真实用户名。

### 字段说明

#### `mcp.enabled`

```json
"enabled": true
```

如果这里不开启，Picoclaw 根本不会加载 MCP server。

#### `servers.privileged`

```json
"privileged": {
  ...
}
```

这只是 MCP server 的配置名，不代表自动授予权限。

#### `type`

```json
"type": "stdio"
```

本方案使用的是本地 stdio MCP server。

#### `command`

```json
"command": "/usr/local/bin/picoclaw-privileged-mcp"
```

必须是**绝对路径**，并且与实际安装路径完全一致。

#### `args`

```json
"args": []
```

当前最小 server 不需要额外命令行参数。

#### `env_file`

```json
"env_file": "/home/YOUR_USER/.picoclaw/secrets/privileged.env"
```

这个文件会为 MCP server 提供 `TOTP_SECRET` 和 `REBOOT_ACTION_MODE`。

### 重要注意事项

- JSON 必须保持合法
- `command` 指向的 binary 必须存在且可执行
- `env_file` 必须存在且对 Picoclaw 运行用户可读
- 配置中的用户身份要与 Picoclaw 实际运行身份一致

---

## 6. Secret env 文件

创建：

- `~/.picoclaw/secrets/privileged.env`

### 推荐内容

参考本仓库示例：

- `examples/privileged.env.example`

最小运行内容应为：

```env
TOTP_SECRET=YOUR_BASE32_SECRET_HERE
REBOOT_ACTION_MODE=harmless
```

该值中的：

- `TOTP_SECRET` 必须与你手机认证器中使用的 TOTP secret 一致
- `REBOOT_ACTION_MODE` 用于控制当前是 harmless 还是 real path

### 要求

- 必须存在 `TOTP_SECRET`
- secret 本身必须有效
- 不要无意义加引号，除非你明确知道当前解析逻辑接受它
- 文件必须对运行 Picoclaw 的用户可读

### 推荐权限

- 目录：`700`
- 文件：`600`

### 为什么单独使用 env 文件

相比把 secret 放进项目目录，这样更合适，因为它：

- 避免 secret 跟源码混在一起
- 更符合 Picoclaw MCP 的 `env_file` 机制
- 回滚与迁移更清晰
- 更不容易误提交进 git

### 不要这样做

不要：

- 提交这个文件
- 把一次性 OTP 写进去
- 把示例 secret 当成真实生产 secret
- 把其他无关 secret 混放进去

---

## 7. 本地 skill

### 源码路径

本仓库中的 skill 源码位于：

- `skills/reboot-guard/SKILL.md`

### 部署路径

它应被复制到目标项目：

- `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`

它只负责识别一种输入格式：

```text
/reboot --otp 123456
```

并映射到 MCP tool：

- `reboot_system`

### 推荐最小 skill 内容

```md
---
name: reboot-guard
description: Strictly maps /reboot --otp 123456 to the reboot_system MCP tool.
---

# Reboot Guard

Only handle messages that consist of exactly three whitespace-separated tokens:

1. `/reboot`
2. `--otp`
3. a 6-digit numeric OTP

If and only if the message matches that exact pattern:

- call MCP tool `reboot_system`
- pass `otp` as the 6-digit code
- do not use shell tools
- do not ask for Linux password
- do not suggest sudo commands

If the pattern does not match, and the user appears to be trying to reboot, reply exactly:

`Usage: /reboot --otp 123456`

Never repeat the OTP in the response.
Never broaden this into general privileged command execution.
```

### 为什么 skill 要保持很窄

保持严格是为了防止它漂移成：

- 通用命令解析器
- 自然语言高权限请求代理
- 任意 sudo 命令 broker
- 意外的权限扩张入口

---

## 8. 示例文件与安装脚本的关系

以下示例文件仍然是 source-of-truth 模板：

- `examples/picoclaw-config.example.json`
- `examples/privileged.env.example`
- `examples/sudoers.example`

安装脚本输出的配置应与它们在语义上保持一致：

- MCP server 名称仍为 `privileged`
- command 仍指向安装后的 MCP binary
- env_file 仍指向 `~/.picoclaw/secrets/privileged.env` 这类私有文件
- sudoers 仍只允许 `/usr/sbin/reboot`

---

## 9. 路径一致性要求

这个方案对路径一致性要求很高。请至少确认以下几项完全一致：

### MCP binary 路径

`config.json` 中的路径必须与实际安装路径一致：

```text
/usr/local/bin/picoclaw-privileged-mcp
```

### Env 文件路径

`env_file` 路径必须与实际 secret 文件一致：

```text
/home/YOUR_USER/.picoclaw/secrets/privileged.env
```

### Skill 路径

skill 必须存在于目标项目：

```text
TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md
```

### Reboot 命令路径

目标主机上 `reboot` 应该确实位于：

```text
/usr/sbin/reboot
```

如果主机实际路径不同，不要直接继续，请先同步修改实现与 sudoers 文档，而不是让安装脚本猜测。

---

## 10. 验证检查清单

在真正测试 reboot 前，请确认：

- `~/.picoclaw/config.json` 中 MCP 已启用
- 对应 MCP server entry 已启用
- `command` 路径存在
- `command` 指向的文件可执行
- `env_file` 路径存在
- `env_file` 中包含 `TOTP_SECRET`
- 当前 `REBOOT_ACTION_MODE` 符合你的测试意图
- 目标项目内存在 `.claude/skills/reboot-guard/SKILL.md`
- Picoclaw 已在配置变更后重启
- 运行 Picoclaw 的用户能读取 env 文件
- 该用户与 sudoers 规则中的用户一致

---

## 11. 常见配置错误

### MCP 没有真正启用

如果忘了：

```json
"enabled": true
```

Picoclaw 根本不会加载 server。

### Binary 路径错误

如果 `command` 路径不对，MCP server 无法启动。

### Env 文件路径错误

如果 `env_file` 指错了位置，常见表现是：

```text
OTP verification is not configured.
```

### Action mode 搞错

如果本来想先 harmless 验证，但 env 文件里写成了：

```env
REBOOT_ACTION_MODE=real
```

那么正确 OTP 会直接进入真实 reboot 路径。

### Skill 装在了错误项目里

项目级 skill 只在对应项目内生效。

### JSON 非法

多余逗号、对象闭合错误都会导致 Picoclaw 无法正确加载配置。

### Secret 文件误提交进 git

请确保目标项目和本仓库都有合适的 `.gitignore`，避免私密文件被提交。

### 与 sudoers 的路径不一致

如果实现使用 `/usr/sbin/reboot`，但 sudoers 允许的是别的路径，那么即使 OTP 通过，最终执行仍会失败。
