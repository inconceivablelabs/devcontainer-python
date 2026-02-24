
# Python + Node.js + Claude Code Development Container
FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

# Arguments for user configuration
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Remove expired Yarn repo from base image
RUN rm -f /etc/apt/sources.list.d/yarn.list || true

# Install Node.js 20.x LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
RUN apt-get update && apt-get install -y nodejs
RUN npm install -g npm@latest

# Install additional development tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        git \
        git-lfs \
        gh \
        curl \
        wget \
        jq \
        unzip \
        ripgrep \
        fd-find \
        tree \
        htop \
        tmux \
        vim \
        less \
        openssh-client \
        gnupg2 \
        # For some Python packages that need compilation
        build-essential \
        libffi-dev \
        libssl-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 (must be done as root)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# Install rbw (unofficial Bitwarden CLI) for secrets management
ARG RBW_VERSION=1.15.0
RUN curl -fsSL "https://github.com/doy/rbw/releases/download/${RBW_VERSION}/rbw_${RBW_VERSION}_linux_amd64.tar.gz" \
    | tar -xz -C /usr/local/bin/ rbw rbw-agent \
    && chmod +x /usr/local/bin/rbw /usr/local/bin/rbw-agent

# Configure npm to use user directory for global packages (allows auto-updates)
# This must be done BEFORE switching to non-root user
RUN mkdir -p /home/${USERNAME}/.npm-global \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.npm-global

# Switch to non-root user for npm global installs
USER $USERNAME

# Configure npm prefix for the user
RUN npm config set prefix "/home/${USERNAME}/.npm-global"

# Install Claude Code via native installer
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install Beads in user's npm directory
RUN npm install -g @beads/bd

# Install common Python development tools
RUN pip install --no-cache-dir \
    poetry \
    pipx \
    black \
    ruff \
    mypy \
    pytest \
    pytest-asyncio \
    ipython \
    httpx \
    python-dotenv \
    pydantic \
    pandas \
    numpy \
    scipy \
    matplotlib
    
# Set up paths for Claude native install, pipx, and npm-global
ENV PATH="/home/${USERNAME}/.claude/bin:/home/${USERNAME}/.npm-global/bin:/home/${USERNAME}/.local/bin:${PATH}"

# Create workspace directory
WORKDIR /workspaces

# Configure git to use the credential helper
RUN git config --global credential.helper store \
    && git config --global init.defaultBranch main \
    && git config --global core.autocrlf input

# Keep container running for dev container use
CMD ["sleep", "infinity"]
