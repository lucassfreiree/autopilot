package connector

import (
	"fmt"
	"sync"

	"github.com/lucassfreiree/autopilot/contracts/connector"
)

// Registry holds all registered connectors keyed by kind.
type Registry struct {
	mu         sync.RWMutex
	connectors map[connector.Kind]connector.Connector
}

// NewRegistry returns an empty connector registry.
func NewRegistry() *Registry {
	return &Registry{connectors: make(map[connector.Kind]connector.Connector)}
}

// Register adds a connector to the registry. Panics on duplicate kind.
func (r *Registry) Register(c connector.Connector) {
	r.mu.Lock()
	defer r.mu.Unlock()
	kind := c.Manifest().Kind
	if _, exists := r.connectors[kind]; exists {
		panic(fmt.Sprintf("connector %q already registered", kind))
	}
	r.connectors[kind] = c
}

// Get returns the connector for the given kind, or an error if not found.
func (r *Registry) Get(kind connector.Kind) (connector.Connector, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	c, ok := r.connectors[kind]
	if !ok {
		return nil, fmt.Errorf("connector %q not registered", kind)
	}
	return c, nil
}

// Manifests returns all registered connector manifests.
func (r *Registry) Manifests() []connector.Manifest {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := make([]connector.Manifest, 0, len(r.connectors))
	for _, c := range r.connectors {
		out = append(out, c.Manifest())
	}
	return out
}
