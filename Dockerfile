# Use the official Golang image as a build stage
FROM golang:1.23.1-alpine3.20 AS builder

# dependencies that sqlite3 needs for compiling
RUN apk add --no-cache gcc musl-dev

# Set the working directory inside the container
WORKDIR /app

# Set an env variable i need for sqlite3
ENV CGO_ENABLED=1

# Copy go.mod and go.sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the entire project
COPY . .

# Build the Go app
RUN go build -o main ./cmd/awesome-go/

# Use a minimal image for the final stage
FROM alpine:latest

# Set the working directory inside the container
WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/main .
COPY ./static/ ./static
COPY ./templates/ ./templates

# Expose the port the app runs on
EXPOSE 8080

# Command to run the app
CMD ["./main"]
