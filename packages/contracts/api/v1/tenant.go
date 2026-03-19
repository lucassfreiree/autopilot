package apiv1

import "time"

// TenantStatus represents the lifecycle state of a tenant.
type TenantStatus string

const (
	TenantStatusActive    TenantStatus = "active"
	TenantStatusSuspended TenantStatus = "suspended"
	TenantStatusDeleted   TenantStatus = "deleted"
)

// Tenant is the top-level isolation unit in the platform.
type Tenant struct {
	ID        string       `json:"id"`
	Slug      string       `json:"slug"`
	Name      string       `json:"name"`
	Status    TenantStatus `json:"status"`
	CreatedAt time.Time    `json:"created_at"`
	UpdatedAt time.Time    `json:"updated_at"`
}

// CreateTenantRequest is the payload for tenant provisioning.
type CreateTenantRequest struct {
	Slug string `json:"slug"`
	Name string `json:"name"`
}

// UpdateTenantRequest carries mutable tenant fields.
type UpdateTenantRequest struct {
	Name   *string       `json:"name,omitempty"`
	Status *TenantStatus `json:"status,omitempty"`
}
