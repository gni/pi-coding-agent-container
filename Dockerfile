# syntax=docker/dockerfile:1

FROM ubuntu:25.10 AS base

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
    nodejs \
    npm \
    git \
    curl \
    wget \
    ca-certificates \
    procps \
    build-essential \
    python3 \
    vim \
    pipx \
    jq \
    && rm -rf /var/lib/apt/lists/*


# -----------------------------------------------------------------------------
# Install GitHub CLI (gh)
# -----------------------------------------------------------------------------
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -U node

FROM base AS release

# Install the pi-coding-agent globally
# We verify the registry connection implicitly during install
RUN npm install -g @mariozechner/pi-coding-agent@0.57.1

# Verify installation
RUN pi --version

# Install packages
RUN pi install npm:token-rate-pi@latest


# Create a non-root user setup
# We use the existing 'node' user (UID 1000) provided by the base image
# Create the .pi directory structure to ensure permissions are correct when mounted
RUN mkdir -p /home/node/.pi/agent && \
    mkdir -p /workspace && \
    chown -R node:node /home/node/ && \
    chown -R node:node /workspace

# Set the working directory to the project workspace
WORKDIR /workspace

# Switch to non-root user for security
USER node

# Install Python packages in user home
RUN pipx ensurepath && \
    pipx install uv pytest pylint

ENTRYPOINT ["pi"]
CMD []
