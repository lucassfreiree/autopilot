package handler

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
	apiv1 "github.com/lucassfreiree/autopilot/contracts/api/v1"
)

// TenantHandler handles tenant CRUD endpoints.
// TODO(phase-1): replace in-memory store with PostgreSQL repository.
type TenantHandler struct {
	logger  *slog.Logger
	tenants map[string]*apiv1.Tenant
}

// NewTenant creates a TenantHandler with an in-memory store.
func NewTenant(logger *slog.Logger) *TenantHandler {
	return &TenantHandler{logger: logger, tenants: make(map[string]*apiv1.Tenant)}
}

// Create handles POST /v1/tenants.
func (h *TenantHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req apiv1.CreateTenantRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, apiv1.ErrInvalidInput, "invalid JSON body")
		return
	}
	if req.Slug == "" || req.Name == "" {
		writeError(w, apiv1.ErrInvalidInput, "slug and name are required")
		return
	}

	now := time.Now().UTC()
	t := &apiv1.Tenant{
		ID:        uuid.New().String(),
		Slug:      req.Slug,
		Name:      req.Name,
		Status:    apiv1.TenantStatusActive,
		CreatedAt: now,
		UpdatedAt: now,
	}
	h.tenants[t.ID] = t
	writeJSON(w, http.StatusCreated, t)
}

// Get handles GET /v1/tenants/{id}.
func (h *TenantHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	t, ok := h.tenants[id]
	if !ok {
		writeError(w, apiv1.ErrNotFound, "tenant not found")
		return
	}
	writeJSON(w, http.StatusOK, t)
}

// Update handles PATCH /v1/tenants/{id}.
func (h *TenantHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	t, ok := h.tenants[id]
	if !ok {
		writeError(w, apiv1.ErrNotFound, "tenant not found")
		return
	}

	var req apiv1.UpdateTenantRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, apiv1.ErrInvalidInput, "invalid JSON body")
		return
	}
	if req.Name != nil {
		t.Name = *req.Name
	}
	if req.Status != nil {
		t.Status = *req.Status
	}
	t.UpdatedAt = time.Now().UTC()
	writeJSON(w, http.StatusOK, t)
}
