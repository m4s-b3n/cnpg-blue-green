FROM golang:1.22-alpine AS builder

WORKDIR /build

COPY images/demo-app/go.mod images/demo-app/go.sum ./
RUN go mod download

COPY images/demo-app/main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /demo-app .

FROM alpine:3.19

# hadolint ignore=DL3018
RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /demo-app /usr/local/bin/demo-app

# demo-app is a database-writer loop with no HTTP endpoint.
HEALTHCHECK NONE

USER nobody:nobody
ENTRYPOINT ["demo-app"]
