package reboot

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"picoclaw-privileged-mcp/internal/security"
)

const (
	realMode             = "real"
	harmlessMode         = "harmless"
	harmlessCommandPath  = "/usr/bin/printf"
	harmlessCommandArg   = "reboot ok\n"
	harmlessSuccessReply = "OTP verified. Reboot test command executed."
)

type Service struct {
	rebootPath string
}

func NewService(rebootPath string) *Service {
	return &Service{
		rebootPath: rebootPath,
	}
}

func (s *Service) Reboot(ctx context.Context, otp string) (string, error) {
	if !isSixDigits(otp) {
		return "Usage: /reboot --otp 123456", fmt.Errorf("invalid otp format")
	}

	if err := security.VerifyTOTP(otp); err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "not configured") {
			return "OTP verification is not configured.", err
		}
		return "OTP verification failed. Reboot request denied.", err
	}

	mode := actionMode()
	cmd := commandForMode(ctx, mode, s.rebootPath)
	if err := cmd.Start(); err != nil {
		return "Failed to execute reboot.", err
	}

	if mode == harmlessMode {
		return harmlessSuccessReply, nil
	}
	return "OTP verified. System is rebooting.", nil
}

func actionMode() string {
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("REBOOT_ACTION_MODE")))
	if mode == harmlessMode {
		return harmlessMode
	}
	return realMode
}

func commandForMode(ctx context.Context, mode, rebootPath string) *exec.Cmd {
	if mode == harmlessMode {
		return exec.CommandContext(ctx, harmlessCommandPath, harmlessCommandArg)
	}
	return exec.CommandContext(ctx, "sudo", rebootPath)
}

func isSixDigits(v string) bool {
	if len(v) != 6 {
		return false
	}
	for _, ch := range v {
		if ch < '0' || ch > '9' {
			return false
		}
	}
	return true
}
