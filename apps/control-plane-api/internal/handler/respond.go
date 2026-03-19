package handler

import (
	"encoding/json"
	"net/http"

	apiv1 "github.com/lucassfreiree/autopilot/contracts/api/v1"
)

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, code apiv1.ErrorCode, message string) {
	writeJSON(w, code.HTTPStatus(), apiv1.APIError{Code: code, Message: message})
}
