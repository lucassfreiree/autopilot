package config

import (
	"fmt"
	"os"
)

// Config holds runtime configuration for the control-plane-api.
type Config struct {
	Addr        string
	DatabaseURL string
	JWTSecret   string
	LogLevel    string
}

// Load reads configuration from environment variables.
func Load() (*Config, error) {
	cfg := &Config{
		Addr:        getEnv("ADDR", ":8080"),
		DatabaseURL: os.Getenv("DATABASE_URL"),
		JWTSecret:   os.Getenv("JWT_SECRET"),
		LogLevel:    getEnv("LOG_LEVEL", "info"),
	}

	if cfg.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}
	if cfg.JWTSecret == "" {
		return nil, fmt.Errorf("JWT_SECRET is required")
	}

	return cfg, nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
