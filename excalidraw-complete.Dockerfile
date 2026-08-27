# Frontend build
FROM node:18 AS frontend-builder
RUN apt-get update && apt-get install -y --no-install-recommends git \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# Clone the patched Excalidraw frontend. Dokploy compose clones may not
# populate the git submodule, so do not COPY excalidraw/ from build context.
RUN git clone --depth 1 --branch multi-canvas https://github.com/BetterAndBetterII/excalidraw.git excalidraw
COPY patches/time.ts ./excalidraw/excalidraw-app/utils/time.ts
RUN cd excalidraw && npm install -g pnpm@9.15.9 && pnpm install && cd excalidraw-app && DISABLE_VITE_CHECKER=true pnpm build:app:docker

# Backend build
FROM golang:alpine AS backend-builder
RUN apk add --no-cache git
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=frontend-builder /app/excalidraw/excalidraw-app/build ./frontend/
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o main .

# Runtime
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=backend-builder /app/main .
EXPOSE 3002
CMD ["./main"]
