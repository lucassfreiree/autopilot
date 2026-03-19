module github.com/lucassfreiree/autopilot/control-plane-api

go 1.22

require (
	github.com/lucassfreiree/autopilot/contracts v0.1.0
	github.com/google/uuid v1.6.0
)

replace github.com/lucassfreiree/autopilot/contracts => ../../packages/contracts
