FROM golang:1.22-alpine AS builder
WORKDIR /src

COPY packages/contracts ./packages/contracts
COPY apps/control-plane-api ./apps/control-plane-api

WORKDIR /src/apps/control-plane-api
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /bin/control-plane-api .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /bin/control-plane-api /control-plane-api
EXPOSE 8080
ENTRYPOINT ["/control-plane-api"]
