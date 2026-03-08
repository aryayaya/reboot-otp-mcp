# Picoclaw Reboot OTP MCP

语言 / Language: **中文** | [English](./README.md)

这是一个面向现有 Picoclaw 部署的、范围极窄的独立集成仓库，用来实现 OTP 保护的 reboot 流程。

它刻意保持很小的安全边界：

- 只允许一个提权动作
- 只允许精确命令路径：`sudo /usr/sbin/reboot`
- 只做本地 TOTP 校验
- 不提供通用 sudo 执行器
- 不提供基于 shell 的提权命令路径
- 不依赖修改 Picoclaw 核心

## 仓库内容

- `mcp-server/`
  - 独立 Go MCP server 源码
- `skills/reboot-guard/`
  - 可复用的 Claude skill 源码
- `docs/`
  - 安装、配置、安全、测试、排障文档
- `examples/`
  - 仅含占位符的可复制配置片段

## 仓库不包含什么

- Picoclaw 核心源码
- 已构建二进制
- `.env` 或真实 secret
- 用户本地运行时配置文件
- 通用提权框架

## 请求链路

```text
/reboot --otp 123456
  -> reboot-guard skill
  -> reboot_system MCP tool
  -> 本地 Go MCP server
  -> 本地 TOTP 校验
  -> sudo /usr/sbin/reboot
```

## 源码路径与部署路径要分开看

这个仓库只负责提供可复用源码与文档。

### 本仓库中的源码路径

- skill 源码：
  - `skills/reboot-guard/SKILL.md`
- MCP 源码：
  - `mcp-server/`
- 示例片段：
  - `examples/`

### 目标机器 / 目标项目中的部署路径

- 安装后的 binary：
  - `/usr/local/bin/picoclaw-privileged-mcp`
- Picoclaw 配置：
  - `~/.picoclaw/config.json`
- secret env 文件：
  - `~/.picoclaw/secrets/privileged.env`
- 安装到目标项目内的 skill：
  - `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`

把这两类路径区分清楚，才能避免把“仓库布局”误当成“运行时布局”。

## 适用环境

- Kali Linux 或 Debian-like Linux
- `systemd`
- `sudo`
- Go 1.25.x
- 已启用 MCP 的 Picoclaw
- 主机上的 reboot 路径为 `/usr/sbin/reboot`

本仓库不面向 Windows 或 macOS。

## 预期行为

唯一支持的命令形状：

```text
/reboot --otp 123456
```

典型返回：

- 格式错误：
  - `Usage: /reboot --otp 123456`
- OTP 错误：
  - `OTP verification failed. Reboot request denied.`
- 未配置 `TOTP_SECRET`：
  - `OTP verification is not configured.`
- 成功：
  - `OTP verified. System is rebooting.`

OTP 不应在用户可见响应或日志中被回显。

## 文档

- [安装](./docs/install.md)
- [配置](./docs/configuration.md)
- [sudoers](./docs/sudoers.md)
- [安全模型](./docs/security.md)
- [故障排查](./docs/troubleshooting.md)
- [开发](./docs/development.md)
- [测试](./docs/testing.md)

目前详细文档仍以中文为主。英文 root README 会保持可见性与基本一致性，但更深层英文文档可能会滞后。

## 非目标

本仓库不提供：

- 任意 root 命令执行
- root shell 包装器
- wildcard sudoers 放行
- 通用 OTP 提权框架
- 对 Picoclaw 核心命令系统的修改

如果以后需要新增其他高权限动作，建议继续沿用同样思路：一个动作，一个窄 MCP tool，一次单独审查。

## License

MIT。
