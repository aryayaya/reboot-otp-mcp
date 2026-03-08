# Sudoers Configuration

本文说明 reboot-otp 流程所需的 sudoers 规则，以及为什么它必须保持**极窄、精确、可审计**。

目标不是授予广泛提权能力。

目标仅仅是：

- 允许运行 Picoclaw 的本地用户执行 `/usr/sbin/reboot`
- 且不需要输入 Linux 密码
- 但前提仍然是本地 MCP server 已先通过 TOTP 校验

因此 sudoers 是整条链路中的一层：

1. skill 限制命令形状
2. MCP server 本地校验 OTP
3. sudoers 只放行一个精确命令路径
4. 不引入通用 shell-based sudo 能力

---

## 1. 为什么需要 sudoers

MCP server 最终执行的是：

```text
sudo /usr/sbin/reboot
```

如果没有对应 sudoers 规则，`sudo` 会要求密码或直接拒绝执行。

这会违背本项目的初衷：

- 避免在 Telegram / chat 工作流中输入长期 Linux 密码

所以这里需要一条**仅允许单个精确命令**的 non-interactive sudo 规则。

---

## 2. 安全目标

安全目标很窄：

- 只允许一个精确的高权限动作
- 明确拒绝其他一切动作

本文**不**以实现以下能力为目标：

- 任意 root 命令执行
- 通用 OTP 提权框架
- wildcard 命令白名单
- root shell
- 多个系统管理命令的大范围放行

如果你把 sudoers 放宽，整个设计的边界也会随之放宽。

---

## 3. 精确命令边界

目标命令是：

```text
/usr/sbin/reboot
```

目标执行形式是：

```text
sudo /usr/sbin/reboot
```

这个路径必须同时与以下三处完全一致：

- MCP server 实际执行的路径
- 主机 `which reboot` 的结果
- sudoers 中允许的路径

三者必须一致。

---

## 4. 需要成立的前提

本文假设：

- 你的系统中的 reboot 位于 `/usr/sbin/reboot`
- Picoclaw 运行在非 root 用户下
- 最终调用 `sudo` 的就是这个用户
- 你只希望为一个命令开放免密码执行
- 你知道真实 OTP 成功后会导致系统重启

在改 sudoers 之前，请先确认主机上的真实 reboot 路径。

预期结果：

```text
/usr/sbin/reboot
```

如果你的系统返回不同路径，请先同步修改实现与文档，不要直接套用本文。

---

## 5. 推荐 sudoers 规则

推荐规则概念上是：

```sudoers
YOUR_USER ALL=(root) NOPASSWD: /usr/sbin/reboot
```

参考示例文件：

- `../examples/sudoers.example`

把：

- `YOUR_USER`

替换成运行 Picoclaw 的真实本地用户。

### 示例

```sudoers
jojo ALL=(root) NOPASSWD: /usr/sbin/reboot
```

---

## 6. 每一部分是什么意思

以这条规则为例：

```sudoers
jojo ALL=(root) NOPASSWD: /usr/sbin/reboot
```

### `jojo`

被允许调用该命令的本地 Unix 用户。

它必须与运行 Picoclaw 的用户一致。

### `ALL`

这是 sudoers 的 host specification 语法。

### `(root)`

允许该命令以 `root` 身份执行。

### `NOPASSWD:`

该命令不再触发交互式密码提示。

### `/usr/sbin/reboot`

这是整个 sudoers 层最关键的安全边界。

---

## 7. 不要允许什么

不要为了方便改成以下宽泛写法。

### 过宽：所有命令

```sudoers
jojo ALL=(root) NOPASSWD: ALL
```

### 过宽：目录级放行

```sudoers
jojo ALL=(root) NOPASSWD: /usr/sbin/*
```

### 过宽：shell 访问

```sudoers
jojo ALL=(root) NOPASSWD: /bin/sh
jojo ALL=(root) NOPASSWD: /bin/bash
```

### 过宽：顺手把其他高权限动作也加进去

这超出了当前仓库“只做 reboot”这一边界。

---

## 8. 如何验证命令路径

在写 sudoers 之前，先确认主机上的真实 reboot 路径。

预期：

```text
/usr/sbin/reboot
```

你需要确保以下三处完全一致：

1. `which reboot` 的输出
2. `mcp-server/` 实现中的执行路径
3. sudoers 规则中允许的路径

---

## 9. 如何确认 Picoclaw 运行用户

sudoers 规则必须授予**真正运行 Picoclaw 的那个本地用户**。

你应该确认：

- Picoclaw service / process 属于哪个 Unix 用户
- MCP server 是否由同一用户启动
- secret env 文件是否对该用户可读

如果规则授予了错误用户，表现往往是：

- OTP 校验成功
- 但最终 reboot 执行失败

---

## 10. 如何更安全地应用 sudoers 修改

修改 sudoers 时请保持：

- 改动尽可能小
- 使用精确绝对路径
- 不碰无关规则
- 不为了方便扩大权限范围

一个常见且更易审计的做法是：

- 使用独立的 sudoers include 文件
- 让文件名清晰表达用途
- 保持规则易于日后审查和删除

---

## 11. 如何验证 sudoers 规则

### Stage 1: 路径一致性

确认：

- 主机上的 reboot 路径是 `/usr/sbin/reboot`
- MCP server 使用 `/usr/sbin/reboot`
- sudoers 允许的也是 `/usr/sbin/reboot`

### Stage 2: 错误 OTP

发送一个错误 OTP。

预期：

- OTP 校验失败
- 不触发重启

### Stage 3: 正确 OTP

发送一个真实有效 OTP。

预期：

- OTP 校验成功
- 最终命令不再请求 Linux 密码
- 机器进入 reboot

### Stage 4: 非目标验证

确认系统**仍然不支持**通过通用命令路径执行任意高权限命令。

---

## 12. 常见错误

### sudoers 里写错用户

如果规则授予的是别的用户，而不是运行 Picoclaw 的用户，最终执行会失败。

### reboot 路径写错

如果主机路径、sudoers 路径、实现路径不一致，会出现看似像权限错误的失败。

### 使用了 wildcard

通配符虽然方便，但会放大权限边界，违背本仓库的安全目标。

### 误以为 OTP 可以替代 sudoers

不能。

OTP 只是应用层授权门。sudoers 仍然负责决定系统是否允许该用户无密码执行最终命令。

### 忽略系统影响

一旦测试成功，系统会真的重启。

如果你还不准备接受这个副作用，先使用 harmless mode。

---

## 13. 回滚

如果你想撤销这项授权，只需回滚对应 sudoers 规则。

回滚后应验证：

- OTP 逻辑也许仍在 MCP 层运行
- 但 `sudo /usr/sbin/reboot` 不应再无密码成功执行
- 于是完整 reboot 流程将不再按设计工作
