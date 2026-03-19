package apiv1

import "net/http"

// ErrorCode is a machine-readable error identifier.
type ErrorCode string

const (
	ErrNotFound          ErrorCode = "NOT_FOUND"
	ErrConflict          ErrorCode = "CONFLICT"
	ErrInvalidInput      ErrorCode = "INVALID_INPUT"
	ErrUnauthorized      ErrorCode = "UNAUTHORIZED"
	ErrForbidden         ErrorCode = "FORBIDDEN"
	ErrInternal          ErrorCode = "INTERNAL_ERROR"
	ErrPreconditionFailed ErrorCode = "PRECONDITION_FAILED"
)

// APIError is the standard error envelope returned by all API endpoints.
type APIError struct {
	Code    ErrorCode `json:"code"`
	Message string    `json:"message"`
	Detail  string    `json:"detail,omitempty"`
}

// HTTPStatus maps a domain error code to an HTTP status code.
func (e ErrorCode) HTTPStatus() int {
	switch e {
	case ErrNotFound:
		return http.StatusNotFound
	case ErrConflict:
		return http.StatusConflict
	case ErrInvalidInput:
		return http.StatusBadRequest
	case ErrUnauthorized:
		return http.StatusUnauthorized
	case ErrForbidden:
		return http.StatusForbidden
	case ErrPreconditionFailed:
		return http.StatusPreconditionFailed
	default:
		return http.StatusInternalServerError
	}
}
