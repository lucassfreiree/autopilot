// Package client provides an HTTP client for the Autopilot Control Plane API.
package client

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	apiv1 "github.com/lucassfreiree/autopilot/contracts/api/v1"
)

// Config holds the client configuration.
type Config struct {
	BaseURL string
	Token   string
	Timeout time.Duration
}

// Client is an HTTP client for the Autopilot API.
type Client struct {
	cfg  Config
	http *http.Client
}

// New creates a new API client with the given configuration.
func New(cfg Config) *Client {
	if cfg.Timeout == 0 {
		cfg.Timeout = 30 * time.Second
	}
	return &Client{cfg: cfg, http: &http.Client{Timeout: cfg.Timeout}}
}

func (c *Client) do(ctx context.Context, method, path string, body, out any) error {
	var bodyReader *bytes.Buffer
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return fmt.Errorf("marshal request: %w", err)
		}
		bodyReader = bytes.NewBuffer(b)
	} else {
		bodyReader = &bytes.Buffer{}
	}

	req, err := http.NewRequestWithContext(ctx, method, c.cfg.BaseURL+path, bodyReader)
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.cfg.Token)

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("do request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		var apiErr apiv1.APIError
		if err := json.NewDecoder(resp.Body).Decode(&apiErr); err != nil {
			return fmt.Errorf("HTTP %d", resp.StatusCode)
		}
		return fmt.Errorf("[%s] %s", apiErr.Code, apiErr.Message)
	}

	if out != nil {
		return json.NewDecoder(resp.Body).Decode(out)
	}
	return nil
}

// CreateTenant provisions a new tenant.
func (c *Client) CreateTenant(ctx context.Context, req apiv1.CreateTenantRequest) (*apiv1.Tenant, error) {
	var t apiv1.Tenant
	if err := c.do(ctx, http.MethodPost, "/v1/tenants", req, &t); err != nil {
		return nil, err
	}
	return &t, nil
}

// GetTenant retrieves a tenant by ID.
func (c *Client) GetTenant(ctx context.Context, id string) (*apiv1.Tenant, error) {
	var t apiv1.Tenant
	if err := c.do(ctx, http.MethodGet, "/v1/tenants/"+id, nil, &t); err != nil {
		return nil, err
	}
	return &t, nil
}

// DispatchWorkflow starts a new workflow run.
func (c *Client) DispatchWorkflow(ctx context.Context, tenantID string, req apiv1.DispatchWorkflowRequest) (*apiv1.WorkflowRun, error) {
	var run apiv1.WorkflowRun
	if err := c.do(ctx, http.MethodPost, "/v1/tenants/"+tenantID+"/workflow-runs", req, &run); err != nil {
		return nil, err
	}
	return &run, nil
}

// GetWorkflowRun retrieves a workflow run by ID.
func (c *Client) GetWorkflowRun(ctx context.Context, tenantID, runID string) (*apiv1.WorkflowRun, error) {
	var run apiv1.WorkflowRun
	if err := c.do(ctx, http.MethodGet, "/v1/tenants/"+tenantID+"/workflow-runs/"+runID, nil, &run); err != nil {
		return nil, err
	}
	return &run, nil
}
