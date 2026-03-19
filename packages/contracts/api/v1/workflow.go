package apiv1

import "time"

// WorkflowStatus is the lifecycle state of a workflow run.
type WorkflowStatus string

const (
	WorkflowStatusPending   WorkflowStatus = "pending"
	WorkflowStatusRunning   WorkflowStatus = "running"
	WorkflowStatusWaiting   WorkflowStatus = "waiting_approval"
	WorkflowStatusSucceeded WorkflowStatus = "succeeded"
	WorkflowStatusFailed    WorkflowStatus = "failed"
	WorkflowStatusCancelled WorkflowStatus = "cancelled"
)

// WorkflowRun represents a single execution of an automation.
type WorkflowRun struct {
	ID           string         `json:"id"`
	TenantID     string         `json:"tenant_id"`
	AutomationID string         `json:"automation_id"`
	Status       WorkflowStatus `json:"status"`
	Inputs       map[string]any `json:"inputs"`
	Outputs      map[string]any `json:"outputs,omitempty"`
	Error        string         `json:"error,omitempty"`
	StartedAt    *time.Time     `json:"started_at,omitempty"`
	FinishedAt   *time.Time     `json:"finished_at,omitempty"`
	CreatedAt    time.Time      `json:"created_at"`
}

// DispatchWorkflowRequest triggers a new run for an automation.
type DispatchWorkflowRequest struct {
	AutomationID string         `json:"automation_id"`
	Inputs       map[string]any `json:"inputs,omitempty"`
}

// ApprovalDecision is submitted by a human reviewer to unblock a waiting run.
type ApprovalDecision struct {
	Approved bool   `json:"approved"`
	Comment  string `json:"comment,omitempty"`
}
