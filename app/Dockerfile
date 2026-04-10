FROM golang:1.22-alpine AS builder

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /demo-app .

FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /demo-app /usr/local/bin/demo-app

USER nobody:nobody
ENTRYPOINT ["demo-app"]
