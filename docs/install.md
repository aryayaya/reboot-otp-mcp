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

## 1. 本指南会安装什么

本指南会安装或配置：

- 从本仓库 `mcp-server/` 构建出的本地 Go MCP server
- 从本仓库 `skills/reboot-guard/SKILL.md` 复制出的本地 Picoclaw skill
- 包含 `TOTP_SECRET` 的私有 env 文件
- `~/.picoclaw/config.json` 中的 MCP server 配置
- 仅允许 `/usr/sbin/reboot` 的 narrow sudoers 规则

它**不会**修改 Picoclaw 核心源码。

---

## 2. 支持环境

本指南面向：

- Kali Linux
- Debian 或 Debian-like Linux
- `systemd`
- `sudo`
- Go 1.25.x
- 已安装并可用的 Picoclaw

默认假设：

- `which reboot` 返回 `/usr/sbin/reboot`
- Picoclaw 运行在你的普通用户身份下
- 你可以重启 Picoclaw user service
- 你可以安全地修改 sudoers

本指南**不面向**：

- Windows
- macOS
- 非 systemd 环境
- `reboot` 不在 `/usr/sbin/reboot` 的环境

---

## 3. 开始前需要准备什么

开始前请确认你已经有：

- 可工作的 Picoclaw
- 本地可用的 Go 1.25.x
- 手机上的认证器 App
- 可编辑：
  - `~/.picoclaw/config.json`
  - sudoers
- 已理解这个功能会导致主机真的执行重启

同时建议你提前决定：

- 是否先使用 harmless validation mode
- 是否直接进入真实 reboot mode

如果不确定，先做 harmless validation。

---

## 4. 本指南涉及的路径

### 本仓库中的源码路径

- MCP server 源码：
  - `mcp-server/`
- skill 源码：
  - `skills/reboot-guard/SKILL.md`
- 示例配置：
  - `examples/`

### 目标部署路径

- Picoclaw 配置：
  - `~/.picoclaw/config.json`
- secret env 文件：
  - `~/.picoclaw/secrets/privileged.env`
- 安装后的 MCP binary：
  - `/usr/local/bin/picoclaw-privileged-mcp`
- 安装到目标项目内的 skill：
  - `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`

如果你的实际部署路径不同，请同步修改配置与文档中的对应位置。

---

## 5. Step 1: 准备 TOTP secret

你需要准备一个 TOTP secret，并同时保存到：

- 手机认证器 App
- 本地主机环境变量来源

推荐流程：

- 生成一个新的 TOTP secret
- 导入到你的认证器 App
- 保留原始 secret，用于后续写入 `TOTP_SECRET`

注意：

- 不要把 secret 提交进 git
- 不要把 secret 发进聊天
- 不要把 secret 粘贴到公开文档
- 把它当作真正的凭据保管

完成本步骤后，你应该拥有：

- 手机上可正常刷新的 6 位 OTP
- 一份待写入本地 env 文件的 raw secret

---

## 6. Step 2: 构建 Go MCP server

从本仓库源码目录构建 MCP server：

- `mcp-server/`

构建结果应为一个可执行文件：

- `picoclaw-privileged-mcp`

构建后建议确认：

- binary 已生成
- binary 可执行
- 构建使用的是 Go 1.25.x

精确构建方式见：

- [`development.md`](./development.md)

---

## 7. Step 3: 安装 MCP binary

把构建出的 binary 安装到稳定路径。

推荐路径：

- `/usr/local/bin/picoclaw-privileged-mcp`

推荐这个路径的原因：

- 容易在 Picoclaw config 中引用
- 不依赖当前工作目录
- 便于后续替换和排查

安装后确认：

- 文件真实存在
- 路径与后续 `config.json` 完全一致
- binary 具有执行权限

---

## 8. Step 4: 创建 secret env 文件

创建私有 env 文件：

- `~/.picoclaw/secrets/privileged.env`

推荐内容见：

- [`../examples/privileged.env.example`](../examples/privileged.env.example)

推荐权限：

- 目录：`700`
- 文件：`600`

为什么单独放一个 env 文件：

- 避免把 secret 放进项目目录
- 更符合 Picoclaw MCP `env_file` 加载方式
- 回滚时更清晰

不要这样做：

- 不要提交这个文件
- 不要把一次性 OTP 写进这个文件
- 不要把示例 secret 当成真实 secret 使用

---

## 9. Step 5: 配置 Picoclaw MCP

编辑：

- `~/.picoclaw/config.json`

你需要：

- 全局启用 MCP
- 增加一个 stdio MCP server
- 指向安装好的 binary
- 指向 secret env 文件

推荐最小示例见：

- [`../examples/picoclaw-config.example.json`](../examples/picoclaw-config.example.json)
- [`configuration.md`](./configuration.md)

编辑后请确认：

- JSON 合法
- MCP 已启用
- binary 路径正确
- env_file 路径正确

---

## 10. Step 6: 安装本地 skill

把本仓库中的 skill 源码：

- `skills/reboot-guard/SKILL.md`

复制到目标项目路径：

- `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`

这个 skill 的职责非常窄：

- 只识别 `/reboot --otp 123456`
- 只调用 MCP tool
- 不请求 Linux 密码
- 不扩展为任意提权执行

skill 内容说明见：

- [`configuration.md`](./configuration.md)

---

## 11. Step 7: 添加 sudoers 规则

添加一个严格收敛的 sudoers 规则，仅允许 Picoclaw 运行用户无密码执行：

- `/usr/sbin/reboot`

推荐示例见：

- [`../examples/sudoers.example`](../examples/sudoers.example)
- [`sudoers.md`](./sudoers.md)

不要授予：

- `ALL`
- 任意 shell
- `/usr/sbin/*`
- 其他未审查的高权限命令

继续前请确认：

- `which reboot` 返回 `/usr/sbin/reboot`
- sudoers 使用的是完全一致的路径
- 该规则授予的是运行 Picoclaw 的那个用户

---

## 12. Step 8: 重启 Picoclaw

重启 Picoclaw user service，让它重新加载：

- MCP 配置
- env_file
- 安装后的 binary
- 目标项目中的 skill

重启后请确认：

- 服务正常运行
- 没有 MCP 启动错误
- 没有配置解析错误

如失败，请看：

- [`troubleshooting.md`](./troubleshooting.md)

---

## 13. Step 9: 安全验证整条链路

建议按以下顺序验证：

### 9.1 错误 OTP

发送：

```text
/reboot --otp 000000
```

预期：

- 被拒绝
- 不重启
- 返回 OTP 验证失败提示

### 9.2 格式错误

发送：

```text
/reboot
```

预期：

- 返回 usage
- 不重启

### 9.3 正确 OTP

发送：

```text
/reboot --otp 123456
```

其中 OTP 为认证器上当前真实有效的 6 位验证码。

预期：

- OTP 被接受
- 系统进入重启链路

如果你还没准备好真的重启机器，请先使用 harmless mode。

---

## 14. 预期命令格式

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

## 15. 成功与失败的典型表现

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

### 成功

```text
OTP verified. System is rebooting.
```

重要：

- 不应回显 OTP
- 不应在日志中打印 OTP

---

## 16. 如果你想先做 harmless dry run

如果你想先验证 Telegram → skill → MCP → OTP 这整条链路，而不真的重启机器，可以暂时把真实 reboot 执行逻辑替换成 harmless command。

这样可以先确认：

- OTP 解析正常
- TOTP 校验正常
- MCP wiring 正常
- Picoclaw 配置正确
- 成功/失败消息符合预期

仅在 harmless path 全部验证通过后，再切换回真实 reboot。

详见：

- [`development.md`](./development.md)
- [`testing.md`](./testing.md)

---

## 17. 卸载 / 回滚

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

## 18. 后续建议阅读

- [`configuration.md`](./configuration.md)
- [`sudoers.md`](./sudoers.md)
- [`security.md`](./security.md)
- [`troubleshooting.md`](./troubleshooting.md)
- [`development.md`](./development.md)
- [`testing.md`](./testing.md)
