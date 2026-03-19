package handler

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
	apiv1 "github.com/lucassfreiree/autopilot/contracts/api/v1"
)

// WorkflowHandler handles workflow dispatch and approval endpoints.
// TODO(phase-2): delegate execution to Temporal workflow worker.
type WorkflowHandler struct {
	logger *slog.Logger
	runs   map[string]*apiv1.WorkflowRun
}

// NewWorkflow creates a WorkflowHandler with an in-memory store.
func NewWorkflow(logger *slog.Logger) *WorkflowHandler {
	return &WorkflowHandler{logger: logger, runs: make(map[string]*apiv1.WorkflowRun)}
}

// Dispatch handles POST /v1/tenants/{tenantId}/workflow-runs.
func (h *WorkflowHandler) Dispatch(w http.ResponseWriter, r *http.Request) {
	tenantID := r.PathValue("tenantId")
	var req apiv1.DispatchWorkflowRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, apiv1.ErrInvalidInput, "invalid JSON body")
		return
	}
	if req.AutomationID == "" {
		writeError(w, apiv1.ErrInvalidInput, "automation_id is required")
		return
	}

	now := time.Now().UTC()
	run := &apiv1.WorkflowRun{
		ID:           uuid.New().String(),
		TenantID:     tenantID,
		AutomationID: req.AutomationID,
		Status:       apiv1.WorkflowStatusPending,
		Inputs:       req.Inputs,
		CreatedAt:    now,
	}
	h.runs[run.ID] = run

	h.logger.Info("workflow dispatched",
		"run_id", run.ID,
		"tenant_id", tenantID,
		"automation_id", req.AutomationID,
	)
	writeJSON(w, http.StatusCreated, run)
}

// Get handles GET /v1/tenants/{tenantId}/workflow-runs/{id}.
func (h *WorkflowHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	run, ok := h.runs[id]
	if !ok {
		writeError(w, apiv1.ErrNotFound, "workflow run not found")
		return
	}
	writeJSON(w, http.StatusOK, run)
}

// Approve handles POST /v1/tenants/{tenantId}/workflow-runs/{id}/approve.
func (h *WorkflowHandler) Approve(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	run, ok := h.runs[id]
	if !ok {
		writeError(w, apiv1.ErrNotFound, "workflow run not found")
		return
	}
	if run.Status != apiv1.WorkflowStatusWaiting {
		writeError(w, apiv1.ErrPreconditionFailed, "workflow run is not waiting for approval")
		return
	}

	var req apiv1.ApprovalDecision
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, apiv1.ErrInvalidInput, "invalid JSON body")
		return
	}

	if req.Approved {
		run.Status = apiv1.WorkflowStatusRunning
	} else {
		run.Status = apiv1.WorkflowStatusCancelled
	}

	h.logger.Info("approval decision recorded",
		"run_id", run.ID,
		"approved", req.Approved,
	)
	writeJSON(w, http.StatusOK, run)
}
