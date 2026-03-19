package event

import "time"

// Topic is a named channel for platform events.
type Topic string

const (
	TopicWorkflowStarted   Topic = "workflow.started"
	TopicWorkflowSucceeded Topic = "workflow.succeeded"
	TopicWorkflowFailed    Topic = "workflow.failed"
	TopicWorkflowWaiting   Topic = "workflow.waiting_approval"
	TopicTenantCreated     Topic = "tenant.created"
	TopicTenantSuspended   Topic = "tenant.suspended"
	TopicConnectorEvent    Topic = "connector.event"
)

// Envelope wraps any platform event with routing metadata.
type Envelope struct {
	ID        string    `json:"id"`
	Topic     Topic     `json:"topic"`
	TenantID  string    `json:"tenant_id"`
	OccurredAt time.Time `json:"occurred_at"`
	Payload   any       `json:"payload"`
}

// Publisher sends events to the platform event bus.
type Publisher interface {
	Publish(env Envelope) error
}

// Subscriber receives events from the platform event bus.
type Subscriber interface {
	Subscribe(topics []Topic, handler func(Envelope)) error
}
