package apiv1

import "time"

// AutomationKind classifies the type of automation.
type AutomationKind string

const (
	AutomationKindRelease   AutomationKind = "release"
	AutomationKindDeploy    AutomationKind = "deploy"
	AutomationKindPromotion AutomationKind = "promotion"
	AutomationKindCustom    AutomationKind = "custom"
)

// Automation is a versioned, reusable automation definition in the catalog.
type Automation struct {
	ID          string         `json:"id"`
	TenantID    string         `json:"tenant_id"`
	Slug        string         `json:"slug"`
	Name        string         `json:"name"`
	Kind        AutomationKind `json:"kind"`
	Description string         `json:"description"`
	Version     string         `json:"version"`
	Schema      InputSchema    `json:"schema"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
}

// InputSchema defines the expected input parameters for an automation.
type InputSchema struct {
	Properties map[string]SchemaProperty `json:"properties"`
	Required   []string                  `json:"required,omitempty"`
}

// SchemaProperty describes a single input field.
type SchemaProperty struct {
	Type        string `json:"type"`
	Description string `json:"description,omitempty"`
	Default     any    `json:"default,omitempty"`
}

// CreateAutomationRequest is the payload for registering a new automation.
type CreateAutomationRequest struct {
	Slug        string         `json:"slug"`
	Name        string         `json:"name"`
	Kind        AutomationKind `json:"kind"`
	Description string         `json:"description"`
	Version     string         `json:"version"`
	Schema      InputSchema    `json:"schema"`
}
