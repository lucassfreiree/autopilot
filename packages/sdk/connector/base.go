// Package connector provides base types and helpers for building Autopilot connectors.
package connector

import (
	"context"
	"fmt"

	"github.com/lucassfreiree/autopilot/contracts/connector"
)

// BaseConnector provides no-op defaults for optional Connector methods.
// Embed it to avoid implementing every interface method from scratch.
type BaseConnector struct {
	manifest connector.Manifest
}

// NewBase creates a BaseConnector with the given manifest.
func NewBase(manifest connector.Manifest) BaseConnector {
	return BaseConnector{manifest: manifest}
}

// Manifest returns the connector's static metadata.
func (b BaseConnector) Manifest() connector.Manifest {
	return b.manifest
}

// Execute is a no-op default that must be overridden by real connectors.
func (b BaseConnector) Execute(_ context.Context, req connector.ExecutionRequest) (connector.ExecutionResult, error) {
	return connector.ExecutionResult{}, fmt.Errorf("connector %s does not implement action %q", b.manifest.Kind, req.Action)
}
