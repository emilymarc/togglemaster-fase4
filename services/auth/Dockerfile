# STAGE 1 — compilar
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o main .

# STAGE 2 — imagem final leve
FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/main .
EXPOSE 8001
CMD ["./main"]