package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/modelcontextprotocol/go-sdk/mcp"

	"picoclaw-privileged-mcp/internal/reboot"
)

type rebootArgs struct {
	OTP string `json:"otp"`
}

type toolResult struct {
	OK      bool   `json:"ok"`
	Message string `json:"message"`
}

func main() {
	logger := log.New(os.Stderr, "[picoclaw-privileged-mcp] ", log.LstdFlags)

	server := mcp.NewServer(&mcp.Implementation{
		Name:    "picoclaw-privileged-mcp",
		Version: "0.1.0",
	}, nil)

	rebootSvc := reboot.NewService("/usr/sbin/reboot")

	server.AddTool(
		&mcp.Tool{
			Name:        "reboot_system",
			Description: "Verify a 6-digit TOTP code and reboot the local system.",
			InputSchema: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"otp": map[string]any{
						"type":        "string",
						"description": "6-digit TOTP code from authenticator app",
					},
				},
				"required": []string{"otp"},
			},
		},
		func(ctx context.Context, req *mcp.CallToolRequest) (*mcp.CallToolResult, error) {
			var args rebootArgs
			if err := decodeArguments(req, &args); err != nil {
				return textResultJSON(toolResult{
					OK:      false,
					Message: "Invalid tool arguments.",
				}), nil
			}

			msg, err := rebootSvc.Reboot(ctx, args.OTP)
			if err != nil {
				logger.Printf("reboot request failed: %v", err)
				return textResultJSON(toolResult{
					OK:      false,
					Message: msg,
				}), nil
			}

			return textResultJSON(toolResult{
				OK:      true,
				Message: msg,
			}), nil
		},
	)

	if err := server.Run(context.Background(), &mcp.StdioTransport{}); err != nil {
		logger.Fatalf("server exited: %v", err)
	}
}

func decodeArguments(req *mcp.CallToolRequest, dst any) error {
	if req == nil || req.Params.Arguments == nil {
		return fmt.Errorf("missing arguments")
	}
	raw, err := json.Marshal(req.Params.Arguments)
	if err != nil {
		return err
	}
	return json.Unmarshal(raw, dst)
}

func textResultJSON(v any) *mcp.CallToolResult {
	data, err := json.Marshal(v)
	if err != nil {
		data = []byte(`{"ok":false,"message":"internal error"}`)
	}
	return &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: string(data)},
		},
	}
}
