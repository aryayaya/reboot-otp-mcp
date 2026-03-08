package reboot

import (
	"context"
	"fmt"
	"os/exec"
	"strings"

	"picoclaw-privileged-mcp/internal/security"
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

	cmd := exec.CommandContext(ctx, "sudo", s.rebootPath)
	if err := cmd.Start(); err != nil {
		return "Failed to execute reboot.", err
	}

	return "OTP verified. System is rebooting.", nil
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
