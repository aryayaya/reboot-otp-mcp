# Development

本文面向开发者，说明如何：

- 构建 Go MCP server
- 替换已安装 binary
- 在不重启机器的前提下做 harmless 联调
- 与 Picoclaw 集成验证
- 在 harmless mode 与真实 reboot mode 之间切换

它不是最终用户安装指南。初次部署请看：

- [`install.md`](./install.md)

---

## 1. 本文的用途

当你需要做以下事情时，请看这份文档：

- 修改 Go MCP server 源码
- 本地构建新版本
- 用新 binary 替换当前安装版本
- 在不真的 reboot 的情况下验证整条链路
- 排查开发阶段的问题

开发阶段的核心原则是：

- 先做 harmless validation，再做真实 reboot 测试

---

## 2. 仓库角色与开发范围

这个仓库故意只做一件事：

1. 接收 `/reboot --otp 123456`
2. 通过目标项目中的 skill 映射到 MCP tool
3. 在本地主机完成 TOTP 校验
4. 最终只允许一个精确高权限动作

开发时应尽量保持这些边界。

---

## 3. 开发环境假设

本文默认假设：

- Linux
- Kali 或 Debian-like 环境
- `systemd`
- `sudo`
- Go 1.25.x
- 已安装并可运行的 Picoclaw
- Picoclaw 已启用 MCP
- 本地已经有一份可用的 TOTP secret

预期高权限命令路径：

```text
/usr/sbin/reboot
```

---

## 4. 关键路径

### 本仓库中的路径

- 仓库根目录：
  - `PROJECT_ROOT/`
- Go MCP server 源码：
  - `PROJECT_ROOT/mcp-server/`
- skill 源码：
  - `PROJECT_ROOT/skills/reboot-guard/SKILL.md`
- 示例配置：
  - `PROJECT_ROOT/examples/`

### 目标部署路径

- 安装后的 binary：
  - `/usr/local/bin/picoclaw-privileged-mcp`
- Picoclaw 配置：
  - `~/.picoclaw/config.json`
- secret env 文件：
  - `~/.picoclaw/secrets/privileged.env`
- 已安装 skill：
  - `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`

排查时请始终确认：

- 你改的是哪份源码
- 你安装的是哪份 binary
- `config.json` 指向的是哪份 binary

---

## 5. 构建 MCP server

从 Go module 目录构建 MCP server：

```bash
cd "PROJECT_ROOT/mcp-server"
GOTOOLCHAIN=go1.25.7 go mod tidy
GOTOOLCHAIN=go1.25.7 go build -o picoclaw-privileged-mcp
```

注意：

- 本机 `/usr/bin/go` 可能是 toolchain launcher
- 不要假设 `GOTOOLCHAIN=local` 一定落到 1.25.x
- 本项目原型联调时使用的是 `GOTOOLCHAIN=go1.25.7`

构建后请确认：

- binary 已生成
- binary 可执行
- 使用的是预期的 Go 1.25.x toolchain

---

## 6. 改源码后如何重建

每当你改动这些内容时，都应重新构建：

- TOTP 校验逻辑
- 返回消息
- reboot 路径
- MCP tool 注册
- 参数解析
- harmless / real reboot 执行逻辑

一个非常常见的开发错误是：

- 改了源码
- 但 Picoclaw 仍在跑旧 binary

---

## 7. 安装开发版 binary

为了做本地集成测试，建议把开发版 binary 安装到与 Picoclaw config 一致的固定路径。

推荐路径：

```text
/usr/local/bin/picoclaw-privileged-mcp
```

安装后请确认：

- 路径正确
- 文件可执行
- 该 binary 就是刚才构建出的版本

不要误以为仓库目录里的 build 产物会自动被 Picoclaw 使用。

---

## 8. Harmless validation mode

在测试真实 reboot 前，强烈建议先做 harmless validation。

它的目的，是验证以下内容而不真的重启机器：

- skill 映射是否正常
- MCP server 是否能启动
- 参数是否解码成功
- TOTP 校验是否生效
- 返回消息是否正确
- Picoclaw 与 MCP 的集成是否正常

### Harmless mode 的典型做法

临时把真实 reboot 执行路径替换成一个简单、可观察、但不会修改关键系统状态的 harmless command。

原型联调时曾临时改成：

```text
printf "reboot ok\n"
```

仅在 harmless path 全部验证通过后，再切换回真实 reboot。

---

## 9. 推荐开发测试顺序

建议按以下顺序联调：

1. 构建 binary
2. 安装开发版 binary
3. 重启 Picoclaw
4. 测 malformed input
5. 测 invalid OTP
6. 在 harmless mode 下测试 valid OTP
7. 切回真实 reboot mode

---

## 10. 从 harmless mode 切回真实 reboot

当 harmless 验证完成后，再恢复真实动作：

```text
sudo /usr/sbin/reboot
```

切换前请确认：

- sudoers 规则已存在
- sudoers 规则中的路径完全一致
- 运行用户与 sudoers 用户一致
- 你已经准备好接受机器立即重启

---

## 11. 如何确认 Picoclaw 已真正使用新版本

你应该寻找这些证据：

- MCP 已启用
- server entry 已加载
- tool 可用
- 请求到达当前 MCP server
- 当前源码中的返回文案真实出现在用户可见响应中

如果你改了响应文本，但 Picoclaw 仍显示旧文本，通常说明：

- 你还在跑旧 binary
- 或者 Picoclaw 没重启成功

---

## 12. 如何读服务日志

当集成行为不符合预期时，应查看 Picoclaw service logs。

日志尤其适合判断：

- 启动失败
- config 加载问题
- MCP process launch 问题
- OTP 成功后的执行错误

注意：

- 不要为了调试打印 `TOTP_SECRET`
- 不要打印用户提交的 OTP

---

## 13. 安全调试原则

开发调试时，优先采用：

- 本地可逆
- 影响面小
- 容易观察
- 不破坏边界

不要为了“先跑通”而放宽 sudoers，也不要把窄输入面改成任意 shell 执行。

---

## 14. 面向发布的检查清单

在你把某个版本视为“可用”之前，至少应确认：

- 功能仍只支持窄范围命令流
- 没有引入任意高权限执行路径
- 所有路径都是绝对路径且保持一致
- secret 仍然在 git 外部
- 响应中不会回显 OTP
- 日志中不会泄漏 OTP 或 secret
- invalid OTP 被拒绝
- valid OTP 在目标模式下表现正确
- 真实 reboot 前已做 harmless 验证
- 文档仍与真实实现路径、文件名、命令路径一致
