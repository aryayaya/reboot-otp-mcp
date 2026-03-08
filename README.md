# Picoclaw Reboot OTP MCP

Language: [中文](./README.zh.md) | **English**

A narrow standalone integration repository for adding OTP-gated reboot to an existing Picoclaw deployment.

It keeps the security boundary intentionally small:

- one privileged action only
- exact command path only: `sudo /usr/sbin/reboot`
- local TOTP verification only
- no generic sudo runner
- no shell-based privileged command path
- no requirement to modify Picoclaw core

## What this repository contains

- `mcp-server/`
  - standalone Go MCP server source
- `skills/reboot-guard/`
  - reusable Claude skill source
- `docs/`
  - installation, configuration, security, testing, and troubleshooting docs
- `examples/`
  - copy-paste config snippets with placeholders only

## What this repository does not contain

- Picoclaw core source code
- a built binary
- `.env` files or real secrets
- user-local runtime config files
- a generic privilege escalation framework

## Request flow

```text
/reboot --otp 123456
  -> reboot-guard skill
  -> reboot_system MCP tool
  -> local Go MCP server
  -> local TOTP verification
  -> sudo /usr/sbin/reboot
```

## Source paths vs deployment paths

This repository is the source of truth for the reusable assets.

### Source paths in this repository

- skill source:
  - `skills/reboot-guard/SKILL.md`
- MCP source:
  - `mcp-server/`
- example snippets:
  - `examples/`

### Deployment paths on the target machine / target project

- installed binary:
  - `/usr/local/bin/picoclaw-privileged-mcp`
- Picoclaw config:
  - `~/.picoclaw/config.json`
- secret env file:
  - `~/.picoclaw/secrets/privileged.env`
- installed skill in the target project:
  - `TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md`

Keeping these distinct avoids the ambiguity between repo layout and runtime layout.

## Supported environment

- Kali Linux or Debian-like Linux
- `systemd`
- `sudo`
- Go 1.25.x
- Picoclaw with MCP support
- host reboot path available at `/usr/sbin/reboot`

This repository is not intended for Windows or macOS.

## Expected behavior

Supported command shape:

```text
/reboot --otp 123456
```

Typical responses:

- malformed input:
  - `Usage: /reboot --otp 123456`
- wrong OTP:
  - `OTP verification failed. Reboot request denied.`
- missing `TOTP_SECRET`:
  - `OTP verification is not configured.`
- success:
  - `OTP verified. System is rebooting.`

OTP values should never be echoed in user-visible responses or logs.

## Documentation

- [Install](./docs/install.md)
- [Configuration](./docs/configuration.md)
- [Sudoers](./docs/sudoers.md)
- [Security](./docs/security.md)
- [Troubleshooting](./docs/troubleshooting.md)
- [Development](./docs/development.md)
- [Testing](./docs/testing.md)

Detailed docs are currently maintained Chinese-first. The English root README is kept current for GitHub visibility, but deeper English translations may lag.

## Non-goals

This repository is not meant to provide:

- arbitrary root command execution
- a root shell wrapper
- wildcard sudoers grants
- a general OTP-gated admin framework
- changes to Picoclaw core command handling

If you need additional privileged actions later, keep using the same pattern: one action, one narrowly scoped MCP tool, one explicit review.

## License

MIT.
