package connector

import "context"

// Kind identifies the connector type (e.g. "github", "gitlab", "kubernetes").
type Kind string

// Capability describes what a connector can do.
type Capability string

const (
	CapabilityTrigger  Capability = "trigger"
	CapabilityExecute  Capability = "execute"
	CapabilityObserve  Capability = "observe"
	CapabilityApproval Capability = "approval"
)

// Manifest declares connector metadata and its supported capabilities.
type Manifest struct {
	Kind         Kind         `json:"kind"`
	Version      string       `json:"version"`
	Description  string       `json:"description"`
	Capabilities []Capability `json:"capabilities"`
}

// ExecutionRequest carries the inputs for a connector action.
type ExecutionRequest struct {
	TenantID     string         `json:"tenant_id"`
	WorkflowRunID string        `json:"workflow_run_id"`
	Action       string         `json:"action"`
	Inputs       map[string]any `json:"inputs"`
}

// ExecutionResult is returned after a connector action completes.
type ExecutionResult struct {
	Success bool           `json:"success"`
	Outputs map[string]any `json:"outputs,omitempty"`
	Error   string         `json:"error,omitempty"`
}

// ObservationEvent is emitted by a connector when it detects a state change.
type ObservationEvent struct {
	TenantID  string         `json:"tenant_id"`
	Source    Kind           `json:"source"`
	EventType string         `json:"event_type"`
	Payload   map[string]any `json:"payload"`
}

// Connector is the interface every connector plugin must implement.
type Connector interface {
	// Manifest returns static metadata about this connector.
	Manifest() Manifest

	// Execute runs an action and returns its result.
	Execute(ctx context.Context, req ExecutionRequest) (ExecutionResult, error)
}

// Observer is an optional extension for connectors that emit events.
type Observer interface {
	Connector
	// Subscribe registers a handler to receive events from this connector.
	Subscribe(ctx context.Context, tenantID string, handler func(ObservationEvent)) error
}
