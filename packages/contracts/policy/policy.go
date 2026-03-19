package policy

// Effect is the outcome of a policy evaluation.
type Effect string

const (
	EffectAllow Effect = "allow"
	EffectDeny  Effect = "deny"
	EffectAudit Effect = "audit"
)

// Input is the evaluation context passed to a policy.
type Input struct {
	TenantID     string         `json:"tenant_id"`
	ActorID      string         `json:"actor_id"`
	Action       string         `json:"action"`
	Resource     string         `json:"resource"`
	Attributes   map[string]any `json:"attributes,omitempty"`
}

// Decision is the result of a policy evaluation.
type Decision struct {
	Effect  Effect `json:"effect"`
	Reason  string `json:"reason,omitempty"`
}

// Evaluator evaluates a policy input and returns a decision.
type Evaluator interface {
	Evaluate(input Input) (Decision, error)
}
