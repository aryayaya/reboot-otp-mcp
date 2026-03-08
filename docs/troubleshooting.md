# Troubleshooting

本文用于排查 reboot-otp 流程中的常见问题。

整条链路分为多层：

```text
/reboot --otp 123456
  -> target-project skill
  -> MCP tool call
  -> local Go MCP server
  -> TOTP verification
  -> sudo /usr/sbin/reboot
```

排查时请按层次进行。

---

## 1. 建议的排查顺序

建议按以下顺序定位：

1. 命令格式是否正确
2. skill 是否安装在正确目标项目
3. Picoclaw 是否已启用 MCP
4. MCP binary 是否存在且能启动
5. `env_file` 是否存在且包含 `TOTP_SECRET`
6. OTP 校验是否正常
7. sudoers 是否允许精确 reboot 路径
8. `/usr/sbin/reboot` 是否真的可执行

---

## 2. 症状索引

### 症状：机器人只回复 usage

可能原因：

- 命令格式不符合严格匹配规则
- skill 正常工作，按设计拒绝了错误输入

### 症状：几乎没反应或行为不像预期

可能原因：

- skill 不在当前目标项目
- MCP 没启用
- 修改配置后没有重启 Picoclaw

### 症状：返回 `OTP verification is not configured.`

可能原因：

- `env_file` 路径错了
- `TOTP_SECRET` 缺失
- Picoclaw 没重启
- env 文件权限不允许读取

### 症状：返回 `OTP verification failed. Reboot request denied.`

可能原因：

- OTP 错误
- 手机与主机 secret 不一致
- 系统时间偏移
- OTP 格式正确但值无效

### 症状：OTP 已成功，但没有真的 reboot

可能原因：

- sudoers 规则缺失
- sudoers 使用了错误路径
- Picoclaw 实际运行用户与你想的不一致
- `reboot` 路径不一致

---

## 3. 命令格式问题

当前唯一支持的输入格式是：

```text
/reboot --otp 123456
```

如果格式不匹配，预期返回：

```text
Usage: /reboot --otp 123456
```

---

## 4. Skill 加载问题

本仓库中的 skill 源码位于：

```text
skills/reboot-guard/SKILL.md
```

部署后应位于：

```text
TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md
```

常见错误：

- skill 放在了另一个仓库
- 目录层级放错了
- 改了 skill，但测试的不是那个目标项目

---

## 5. MCP 配置问题

Picoclaw 必须启用 MCP，并且 server 配置要正确。

相关文件：

```text
~/.picoclaw/config.json
```

常见错误：

- MCP 全局未启用
- 目标 server entry 被禁用
- `command` 指向错误路径
- `env_file` 指向错误文件
- JSON 编辑后出现语法错误

---

## 6. MCP server 启动问题

安装后的 binary 必须真实存在且可执行。

推荐路径：

```text
/usr/local/bin/picoclaw-privileged-mcp
```

常见错误：

- binary 根本没安装
- config 指向的不是当前安装路径
- binary 不可执行
- 构建失败，但旧 binary 仍留在原处

---

## 7. Secret env 文件问题

MCP server 需要从 `env_file` 中读取 `TOTP_SECRET`。

推荐文件：

```text
~/.picoclaw/secrets/privileged.env
```

缺失 secret 时，常见返回是：

```text
OTP verification is not configured.
```

你应该确认：

- 文件存在
- 文件路径与 `env_file` 一致
- 文件中有 `TOTP_SECRET=...`
- secret 非空
- 运行 Picoclaw 的用户有读取权限

---

## 8. OTP 校验问题

如果系统返回：

```text
OTP verification failed. Reboot request denied.
```

通常说明问题发生在 OTP 层，而不是 reboot 层。

常见原因：

- 6 位 OTP 错误
- 手机认证器使用的是另一个 secret
- 主机上的 secret 更新过，但手机没更新
- 系统时间偏移

---

## 9. Sudoers 与提权执行问题

如果 OTP 校验成功，但 reboot 没发生，问题通常落在 sudoers 或用户身份映射上。

你应该确认：

- 运行 Picoclaw 的用户与 sudoers 里的用户一致
- sudoers 允许的是 `/usr/sbin/reboot`
- 主机上的 reboot 路径与实现一致

---

## 10. Reboot 路径问题

本方案假定：

```text
/usr/sbin/reboot
```

三者必须一致：

- 主机上的真实路径
- `mcp-server/` 代码中的路径
- sudoers 中的路径

---

## 11. Picoclaw 重启问题

在修改以下内容之后，通常都需要重启 Picoclaw：

- `config.json`
- env 文件
- 安装后的 MCP binary
- 目标项目中的 skill

如果服务还在旧状态，你会误以为“修改没效果”。

---

## 12. 安全验证建议流程

如果你不确定问题在哪一层，建议这样测：

### Step 1: 测格式错误

```text
/reboot
```

预期：返回 usage

### Step 2: 测错误 OTP

```text
/reboot --otp 000000
```

预期：OTP 被拒绝且不重启

### Step 3: 测 harmless success path

如果当前支持 harmless mode，优先走这条。

### Step 4: 最后才测真实 reboot

只有在前面都正确时，再去执行真实 reboot 测试。

---

## 13. 求助前建议收集什么信息

建议先整理以下**非敏感**信息：

- 具体症状是什么
- 用户可见返回消息是什么
- 改配置后是否已重启 Picoclaw
- MCP binary 路径是否存在
- env 文件是否存在
- `TOTP_SECRET` 是否已配置
- 运行用户是否与 sudoers 规则一致
- `which reboot` 是否与你文档一致

不要分享：

- `TOTP_SECRET`
- 当前 OTP
- 其他凭据
