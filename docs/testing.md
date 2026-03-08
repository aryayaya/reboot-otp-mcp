# Testing

本文用于说明如何安全、可预测地验证 reboot-otp 流程。

测试目标是确认系统能够：

- 只接受预期命令格式
- 拒绝错误 OTP
- 接受正确 OTP
- 保持高权限动作范围极窄
- 在 Picoclaw + MCP 的整条链路上正常工作
- 不在响应或日志中泄漏敏感值

本文明确区分 harmless validation 与真实 reboot 测试。

---

## 1. 前置条件

开始测试前，请先确认：

- 目标项目内 skill 已安装
- Picoclaw 已启用 MCP
- MCP binary 已安装
- 最近一次改动后 Picoclaw 已重启
- env 文件存在且包含 `TOTP_SECRET`
- 手机认证器使用的 secret 与主机一致
- 你知道当前 binary 是 harmless 还是 real reboot 版本
- 如果要测真实 reboot，sudoers 已允许精确 reboot 路径

---

## 2. 推荐测试顺序

建议按以下顺序执行：

1. malformed command
2. missing OTP
3. non-numeric 或错误长度 OTP
4. 错误但格式合法的 OTP
5. harmless mode 下的正确 OTP
6. 路径一致性回归检查
7. 真实 reboot 测试

---

## 3. 命令解析测试

唯一支持的命令格式是：

```text
/reboot --otp 123456
```

### 测试：缺少 OTP

```text
/reboot
```

预期：

```text
Usage: /reboot --otp 123456
```

### 测试：缺少 `--otp`

```text
/reboot 123456
```

预期：

```text
Usage: /reboot --otp 123456
```

### 测试：多余 token

```text
/reboot --otp 123456 now
```

预期：

```text
Usage: /reboot --otp 123456
```

### 测试：非 6 位 OTP

```text
/reboot --otp 12345
```

预期：

```text
Usage: /reboot --otp 123456
```

---

## 4. OTP 拒绝测试

### 测试：格式合法但值错误的 OTP

```text
/reboot --otp 000000
```

预期返回：

```text
OTP verification failed. Reboot request denied.
```

预期副作用：

- 不发生 reboot

### 测试：缺少 `TOTP_SECRET`

在未向 MCP server 提供 `TOTP_SECRET` 的情况下，请求应返回：

```text
OTP verification is not configured.
```

---

## 5. Harmless mode 下的成功测试

这是强烈推荐的端到端验证方式，应在真实 reboot 前完成。

### 测试：harmless mode 下输入正确 OTP

```text
/reboot --otp 123456
```

其中 OTP 必须是当前真实有效值。

预期结果：

- 返回成功响应
- harmless command 被执行
- 不发生真实 reboot

原型联调中的一个典型成功消息可能是：

```text
OTP verified. Reboot test command executed.
```

这个测试通常可以证明以下几层已连通：

- 命令解析
- skill 映射
- MCP tool 调用
- 参数解码
- TOTP 校验
- 响应生成
- Picoclaw 集成

---

## 6. 真实 reboot 测试

只有当 harmless mode 全部通过后，才建议执行这一测试。

### 前置确认

开始之前请确认：

- 当前 binary 已切回真实 reboot mode
- 实现使用的是 `/usr/sbin/reboot`
- sudoers 允许的是完全一致的路径
- 你接受机器会立即重启

### 测试：real mode 下输入正确 OTP

```text
/reboot --otp 123456
```

其中 OTP 为当前有效值。

预期返回：

```text
OTP verified. System is rebooting.
```

预期副作用：

- 机器重启
- 远程连接可能断开

---

## 7. 回归检查

在代码或配置发生变化后，建议至少重跑以下回归项：

- 输入边界回归
- OTP 拒绝回归
- 成功路径回归
- Secret 处理回归
- 路径一致性回归

### Secret 处理回归

确认：

- 响应中不回显 OTP
- 日志中不出现 OTP
- 日志中不出现 `TOTP_SECRET`

### 路径一致性回归

确认以下路径仍保持一致：

- 主机上的 reboot 路径
- 代码中的 reboot 路径
- sudoers 中的 reboot 路径
- `config.json` 中的 binary 路径

---

## 8. 不要随意测试什么

不要为了“先跑通”而随意做以下事情：

- 把 sudoers 改成更宽范围
- 使用 wildcard command permission
- 为调试打印 OTP
- 为调试打印 `TOTP_SECRET`
- 在共享聊天里发送真实 secret
- 在不确认模式的情况下直接做真实 reboot 测试

测试的目的是验证窄边界是否成立，而不是绕过它。

---

## 9. 测试结果检查清单

当以下全部为真时，可以认为构建状态较好：

- 错误格式返回 usage
- 错误 OTP 不会导致 reboot
- 缺少 `TOTP_SECRET` 时返回 `OTP verification is not configured.`
- 正确 OTP 能在 harmless mode 下先通过
- 明确启用 real reboot 后，正确 OTP 才触发真实 reboot
- 机器只会在预期成功路径下重启
- 响应中不泄漏 secret
- 日志中不泄漏 secret
- 命令面仍然保持狭窄
- 没有出现通用高权限执行路径
