package handler

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
	apiv1 "github.com/lucassfreiree/autopilot/contracts/api/v1"
)

// AutomationHandler handles automation catalog endpoints.
// TODO(phase-1): replace in-memory store with PostgreSQL repository.
type AutomationHandler struct {
	logger      *slog.Logger
	automations map[string]*apiv1.Automation
}

// NewAutomation creates an AutomationHandler with an in-memory store.
func NewAutomation(logger *slog.Logger) *AutomationHandler {
	return &AutomationHandler{logger: logger, automations: make(map[string]*apiv1.Automation)}
}

// Create handles POST /v1/tenants/{tenantId}/automations.
func (h *AutomationHandler) Create(w http.ResponseWriter, r *http.Request) {
	tenantID := r.PathValue("tenantId")
	var req apiv1.CreateAutomationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, apiv1.ErrInvalidInput, "invalid JSON body")
		return
	}
	if req.Slug == "" || req.Name == "" {
		writeError(w, apiv1.ErrInvalidInput, "slug and name are required")
		return
	}

	now := time.Now().UTC()
	a := &apiv1.Automation{
		ID:          uuid.New().String(),
		TenantID:    tenantID,
		Slug:        req.Slug,
		Name:        req.Name,
		Kind:        req.Kind,
		Description: req.Description,
		Version:     req.Version,
		Schema:      req.Schema,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	h.automations[a.ID] = a
	writeJSON(w, http.StatusCreated, a)
}

// List handles GET /v1/tenants/{tenantId}/automations.
func (h *AutomationHandler) List(w http.ResponseWriter, r *http.Request) {
	tenantID := r.PathValue("tenantId")
	var result []*apiv1.Automation
	for _, a := range h.automations {
		if a.TenantID == tenantID {
			result = append(result, a)
		}
	}
	if result == nil {
		result = []*apiv1.Automation{}
	}
	writeJSON(w, http.StatusOK, result)
}

// Get handles GET /v1/tenants/{tenantId}/automations/{id}.
func (h *AutomationHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	a, ok := h.automations[id]
	if !ok {
		writeError(w, apiv1.ErrNotFound, "automation not found")
		return
	}
	writeJSON(w, http.StatusOK, a)
}
