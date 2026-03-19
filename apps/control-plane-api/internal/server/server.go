package server

import (
	"log/slog"
	"net/http"

	"github.com/lucassfreiree/autopilot/control-plane-api/internal/config"
	"github.com/lucassfreiree/autopilot/control-plane-api/internal/handler"
	"github.com/lucassfreiree/autopilot/control-plane-api/internal/middleware"
)

// New builds and returns the HTTP server with all routes registered.
func New(cfg *config.Config, logger *slog.Logger) *http.Server {
	mux := http.NewServeMux()

	th := handler.NewTenant(logger)
	ah := handler.NewAutomation(logger)
	wh := handler.NewWorkflow(logger)

	// Health
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	// Tenants
	mux.HandleFunc("POST /v1/tenants", th.Create)
	mux.HandleFunc("GET /v1/tenants/{id}", th.Get)
	mux.HandleFunc("PATCH /v1/tenants/{id}", th.Update)

	// Automations (per tenant)
	mux.HandleFunc("POST /v1/tenants/{tenantId}/automations", ah.Create)
	mux.HandleFunc("GET /v1/tenants/{tenantId}/automations", ah.List)
	mux.HandleFunc("GET /v1/tenants/{tenantId}/automations/{id}", ah.Get)

	// Workflow runs
	mux.HandleFunc("POST /v1/tenants/{tenantId}/workflow-runs", wh.Dispatch)
	mux.HandleFunc("GET /v1/tenants/{tenantId}/workflow-runs/{id}", wh.Get)
	mux.HandleFunc("POST /v1/tenants/{tenantId}/workflow-runs/{id}/approve", wh.Approve)

	stack := middleware.Chain(
		middleware.RequestID,
		middleware.Logger(logger),
		middleware.Recover(logger),
	)

	return &http.Server{
		Addr:    cfg.Addr,
		Handler: stack(mux),
	}
}
