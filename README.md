思路：
clawhub装totp的skill + mcp + 增加sudoer NOPASS 


# Picoclaw Reboot OTP MCP

语言 / Language: **中文** | [English](./README.en.md)

这是一个面向现有 Picoclaw 部署的、范围极窄的独立集成仓库，用来实现 OTP 保护的 reboot 流程。

它刻意保持很小的安全边界：

- 只允许一个提权动作
- 只允许精确命令路径：`sudo /usr/sbin/reboot`
- 只做本地 TOTP 校验
- 不提供通用 sudo 执行器
- 不提供基于 shell 的提权命令路径
- 不依赖修改 Picoclaw 核心

## 快速开始

clone 后，先运行引导式安装脚本：

```bash
bash ./scripts/install-reboot-otp.sh
```

这个脚本是“半交互式引导安装”，不是黑盒一键部署。它会先做前置检查，再询问部署路径与模式，展示将要写入的配置和 sudoers 行，只有在你确认后才会写入可安全自动化的部分，并把高权限步骤保持为显式人工操作。

完整说明见：

- [安装](./docs/install.md)
- [测试](./docs/testing.md)
- [配置](./docs/configuration.md)

## 仓库内容

- `mcp-server/`
  - 独立 Go MCP server 源码
- `skills/reboot-guard/`
  - 可复用的 Claude skill 源码
- `scripts/install-reboot-otp.sh`
  - 半交互式引导安装脚本
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
- 黑盒一键部署脚本

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

- 引导安装脚本：
  - `scripts/install-reboot-otp.sh`
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

## 引导安装脚本会做什么

安装脚本只自动化那些可审计、可预览、确定性的步骤：

1. 检查 Linux、systemd、sudo、Go、`/usr/sbin/reboot` 和 `GOTOOLCHAIN=go1.25.7`
2. 收集目标项目路径、运行用户/家目录、安装路径、动作模式、TOTP secret 处理方式
3. 在任何写入前展示计算后的部署值
4. 从 `mcp-server/` 构建并安装 MCP binary
5. 把 `skills/reboot-guard/SKILL.md` 复制进目标项目
6. 在安全条件下可选写入 secret env 文件和新的最小 Picoclaw config
7. 打印 sudoers 推荐内容，供人工复核和应用
8. 输出最终验证清单并指向测试文档

如果目标机器上已经存在 `~/.picoclaw/config.json`，脚本不会盲目 patch JSON，而是打印可合并的配置片段。

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
- harmless 成功：
  - `OTP verified. Reboot test command executed.`
- real reboot 成功：
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
