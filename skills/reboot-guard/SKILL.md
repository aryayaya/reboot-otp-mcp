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
