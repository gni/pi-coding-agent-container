# syntax=docker/dockerfile:1

FROM node:22-bookworm-slim AS base

# Set environment variables for production and non-interactive installation
ENV NODE_ENV=production
ENV DEBIAN_FRONTEND=noninteractive
ENV NPM_CONFIG_LOGLEVEL=warn

# Install essential system tools required by pi-coding-agent and common dev workflows
# - git: Required for 'pi install git:...' and version control operations
# - curl/wget: For downloading external resources
# - procps: For process monitoring
# - build-essential: For compiling native add-ons (if extensions require them)
# - ca-certificates: Ensure SSL connections work securely
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    ca-certificates \
    procps \
    build-essential \
    python3 \
    && rm -rf /var/lib/apt/lists/*


FROM base AS release

# Install the pi-coding-agent globally
# We verify the registry connection implicitly during install
RUN npm install -g @mariozechner/pi-coding-agent

# Create a non-root user setup
# We use the existing 'node' user (UID 1000) provided by the base image
# Create the .pi directory structure to ensure permissions are correct when mounted
RUN mkdir -p /home/node/.pi/agent && \
    mkdir -p /workspace && \
    chown -R node:node /home/node/.pi && \
    chown -R node:node /workspace

# Set the working directory to the project workspace
WORKDIR /workspace

# Switch to non-root user for security
USER node

# Verify installation
RUN pi --version

ENTRYPOINT ["pi"]
CMD []
