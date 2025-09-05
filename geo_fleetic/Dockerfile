# Use the official Elixir image
FROM elixir:1.18.4-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    build-base \
    nodejs \
    npm \
    postgresql-client \
    postgis

# Set working directory
WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix.exs and mix.lock
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get --only prod

# Copy the rest of the application
COPY . .

# Compile the application
RUN MIX_ENV=prod mix compile

# Build assets
RUN cd assets && npm install && npm run deploy
RUN mix phx.digest

# Create release
RUN MIX_ENV=prod mix release

# Production stage
FROM alpine:3.18 AS runner

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    ncurses-libs \
    postgresql-client \
    postgis \
    bash \
    openssl

# Create non-root user
RUN addgroup -g 1001 -S appuser && \
    adduser -S -D -H -u 1001 -h /app -s /bin/bash -G appuser -g appuser appuser

# Set working directory
WORKDIR /app

# Copy release from builder stage
COPY --from=builder /app/_build/prod/rel/geo_fleetic ./

# Create necessary directories
RUN mkdir -p /app/data && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Set environment variables
ENV MIX_ENV=prod
ENV PORT=4000
ENV DATABASE_URL=${DATABASE_URL}

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Expose port
EXPOSE ${PORT}

# Start the application
CMD ["bin/geo_fleetic", "start"]