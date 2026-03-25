
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
        fzf \
        bat \
        sqlite3 \
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

# Symlink Debian-renamed binaries to standard names
RUN ln -s /usr/bin/batcat /usr/local/bin/bat \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd

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

# Install Dolt (version-controlled SQL database for Beads task tracking)
ARG DOLT_VERSION=1.82.6
RUN curl -fsSL "https://github.com/dolthub/dolt/releases/download/v${DOLT_VERSION}/dolt-linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/bin/ --strip-components=2 dolt-linux-amd64/bin/dolt \
    && chmod +x /usr/local/bin/dolt

# Install DuckDB CLI (analytics database for CSV/Parquet/SQLite queries)
ARG DUCKDB_VERSION=1.5.0
RUN curl -fsSL "https://github.com/duckdb/duckdb/releases/download/v${DUCKDB_VERSION}/duckdb_cli-linux-amd64.gz" \
    | gunzip > /usr/local/bin/duckdb \
    && chmod +x /usr/local/bin/duckdb

# Install yq (YAML processor)
ARG YQ_VERSION=4.52.4
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# Install sd (sed alternative with simpler syntax)
ARG SD_VERSION=1.1.0
RUN curl -fsSL "https://github.com/chmln/sd/releases/download/v${SD_VERSION}/sd-v${SD_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin/ --wildcards '*/sd' \
    && chmod +x /usr/local/bin/sd

# Install xh (modern HTTP client)
ARG XH_VERSION=0.25.3
RUN curl -fsSL "https://github.com/ducaale/xh/releases/download/v${XH_VERSION}/xh-v${XH_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin/ --wildcards '*/xh' \
    && chmod +x /usr/local/bin/xh

# Install eza (modern ls replacement)
ARG EZA_VERSION=0.23.4
RUN curl -fsSL "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin/ ./eza \
    && chmod +x /usr/local/bin/eza

# Install delta (git diff viewer)
ARG DELTA_VERSION=0.18.2
RUN curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin/ --wildcards '*/delta' \
    && chmod +x /usr/local/bin/delta

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

# Install Beads in user's npm directory (pinned to prevent breaking changes)
ARG BEADS_VERSION=0.62.0
RUN npm install -g @beads/bd@${BEADS_VERSION}

# Install common Python development tools
RUN pip install --no-cache-dir \
    poetry \
    pipx \
    ruff \
    pyright \
    pre-commit \
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

# Configure git to use the credential helper and global pre-commit hooks
RUN git config --global credential.helper store \
    && git config --global init.defaultBranch main \
    && git config --global core.autocrlf input \
    && git config --global core.hooksPath /home/${USERNAME}/.git-hooks \
    && git config --global core.pager delta \
    && git config --global interactive.diffFilter "delta --color-only" \
    && git config --global delta.navigate true \
    && git config --global delta.side-by-side true

# Install global pre-commit hook (delegates to pre-commit framework if config exists)
RUN mkdir -p /home/${USERNAME}/.git-hooks \
    && printf '#!/bin/bash\n\
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"\n\
if [ -f "$REPO_ROOT/.pre-commit-config.yaml" ]; then\n\
    if command -v pre-commit &>/dev/null; then\n\
        exec pre-commit run --hook-stage pre-commit\n\
    else\n\
        echo "WARNING: .pre-commit-config.yaml found but pre-commit is not installed"\n\
        exit 1\n\
    fi\n\
fi\n' > /home/${USERNAME}/.git-hooks/pre-commit \
    && chmod +x /home/${USERNAME}/.git-hooks/pre-commit

# Keep container running for dev container use
CMD ["sleep", "infinity"]
