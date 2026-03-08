package security

import (
	"fmt"
	"os"
	"time"

	"github.com/pquerna/otp"
	"github.com/pquerna/otp/totp"
)

func VerifyTOTP(token string) error {
	secret := os.Getenv("TOTP_SECRET")
	if secret == "" {
		return fmt.Errorf("otp verification is not configured")
	}

	valid, err := totp.ValidateCustom(
		token,
		secret,
		time.Now(),
		totp.ValidateOpts{
			Period:    30,
			Skew:      2,
			Digits:    otp.DigitsSix,
			Algorithm: otp.AlgorithmSHA1,
		},
	)
	if err != nil {
		return fmt.Errorf("otp verification failed")
	}
	if !valid {
		return fmt.Errorf("otp verification failed")
	}

	return nil
}
