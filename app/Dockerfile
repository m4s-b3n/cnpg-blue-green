FROM golang:1.22-alpine AS builder

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /demo-logger .

FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /demo-logger /usr/local/bin/demo-logger

USER nobody:nobody
ENTRYPOINT ["demo-logger"]
