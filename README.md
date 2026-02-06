# Python Devcontainer Image

Shared development container image for Python projects with Claude Code, Node.js, and common development tools.

## What's Included

- Python 3.12 (Debian Bookworm)
- Node.js 20.x LTS
- Claude Code (native installer)
- Beads task tracking (`bd`)
- AWS CLI v2
- Common Python tools: poetry, pipx, black, ruff, mypy, pytest, httpx, pydantic
- Development utilities: git, gh, ripgrep, fd, jq, tmux, vim

## First-Time Host Setup

Before using this devcontainer, create the shared config directories on your host machine. This only needs to be done once per machine.

```bash
# Create shared config directory
mkdir -p ~/.config/claude-shared

# Initialize the Claude config file (IMPORTANT: must be a file, not directory)
echo '{}' > ~/.config/claude-shared/.claude.json

# Create directories for beads and journal
mkdir -p ~/.config/claude-shared/.beads
mkdir -p ~/.config/claude-shared/.private-journal

# Create secrets directory
mkdir -p ~/.secrets
touch ~/.secrets/.env  # Add your secrets here (ANTHROPIC_API_KEY, etc.)
```

## Using in a New Project

1. Create `.devcontainer/devcontainer.json` in your project:

```json
{
  "name": "Python Dev",
  "image": "ghcr.io/inconceivablelabs/devcontainer-python:latest",
  "runArgs": ["--name", "claude-remote", "--hostname", "claude-remote"],

  "mounts": [
    "source=${localEnv:HOME}/.secrets/.env,target=/home/vscode/.env,type=bind,readonly",
    "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly",
    "source=python-pip-cache,target=/home/vscode/.cache/pip,type=volume",
    "source=python-dev-aws-config,target=/home/vscode/.aws,type=volume",
    "source=python-dev-claude-config,target=/home/vscode/.claude,type=volume",
    "source=python-dev-bashhistory,target=/home/vscode/.bash_history,type=volume",
    "source=${localEnv:HOME}/.config/claude-shared/.claude.json,target=/home/vscode/.claude.json,type=bind",
    "source=${localEnv:HOME}/.config/claude-shared/.beads,target=/home/vscode/.beads,type=bind",
    "source=${localEnv:HOME}/.config/claude-shared/.private-journal,target=/home/vscode/.private-journal,type=bind",
    "source=/mnt/c/Users/tboot/Downloads,target=/home/vscode/cdrive,type=bind"
  ],

  "forwardPorts": [8000, 8080, 5000, 3000],

  "containerEnv": {
    "DOTENV_PATH": "/home/vscode/.env",
    "PYTHONDONTWRITEBYTECODE": "1",
    "PYTHONUNBUFFERED": "1"
  },

  "postCreateCommand": {
    "load-env": "echo 'source /home/vscode/.env 2>/dev/null || true' >> ~/.bashrc",
    "git-config": "git config --global --add safe.directory /workspaces",
    "gh-git-auth": "gh auth setup-git || true",
    "beads-claude": "bd setup claude || true",
    "install-deps": "[ -f requirements.txt ] && pip install -r requirements.txt || [ -f pyproject.toml ] && pip install -e . || true"
  },

  "customizations": {
    "vscode": {
      "settings": {
        "python.defaultInterpreterPath": "/usr/local/bin/python",
        "editor.formatOnSave": true,
        "editor.defaultFormatter": "charliermarsh.ruff"
      },
      "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "charliermarsh.ruff",
        "Anthropic.claude-code",
        "eamodio.gitlens"
      ]
    }
  },

  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {}
  },

  "remoteUser": "vscode"
}
```

2. Open the project in VS Code and select "Reopen in Container"

## How It Works

### Shared vs Project-Specific Data

| Data | Storage | Shared Across Projects? |
|------|---------|------------------------|
| Claude Code settings, hooks, plugins | `~/.claude/` (Docker volume) | Yes |
| MCP servers, OAuth | `~/.claude.json` (bind mount) | Yes |
| Beads tasks | `~/.beads/` (bind mount) | Yes |
| Private journal | `~/.private-journal/` (bind mount) | Yes |
| AWS credentials | `~/.aws/` (Docker volume) | Yes |
| Session history | `~/.claude/projects/` | Per project path |
| pip cache | `~/.cache/pip/` (Docker volume) | Yes |

### Why Bind Mounts vs Docker Volumes?

- **Bind mounts** (`${localEnv:HOME}/...`): Data stored on your host, survives container deletion, easily backed up
- **Docker volumes** (`source=volume-name`): Data managed by Docker, faster I/O, persists across rebuilds

## Updating the Base Image

When you need to add tools or change the base configuration:

1. Clone this repo:
   ```bash
   git clone https://github.com/inconceivablelabs/devcontainer-python.git
   cd devcontainer-python
   ```

2. Edit the `Dockerfile`

3. Commit and push to `main`:
   ```bash
   git add Dockerfile
   git commit -m "Add new tool X"
   git push
   ```

4. GitHub Actions automatically builds and pushes to `ghcr.io/inconceivablelabs/devcontainer-python:latest`

5. In your projects, rebuild containers to get the update:
   - VS Code: `Ctrl+Shift+P` → "Dev Containers: Rebuild Container"
   - CLI: `devcontainer up --remove-existing-container`

### Manual Build Trigger

To rebuild without changing the Dockerfile, go to [Actions](https://github.com/inconceivablelabs/devcontainer-python/actions) and click "Run workflow".

## Pulling Updates in Projects

When the base image is updated, your existing containers won't automatically update. To get the latest:

**VS Code:**
1. `Ctrl+Shift+P` → "Dev Containers: Rebuild Container"

**CLI:**
```bash
docker pull ghcr.io/inconceivablelabs/devcontainer-python:latest
devcontainer up --remove-existing-container
```

## Troubleshooting

### "No such file" errors on container start

The bind mounts require files/directories to exist on your host before starting the container. Run the First-Time Host Setup commands above.

### MCP servers not showing up

MCP servers are stored in `~/.claude.json` under project-specific keys. To make them available globally, move them to the root `mcpServers` key:

```json
{
  "mcpServers": {
    "your-server": { ... }
  }
}
```

### Claude Code shows npm deprecation warning

The image uses the native Claude installer. If you see npm warnings, you may have an old cached image. Run:
```bash
docker pull ghcr.io/inconceivablelabs/devcontainer-python:latest
```
Then rebuild your container.

## Projects Using This Image

- [health_condition_poc](https://github.com/inconceivablelabs/health_condition_poc)
- [personal-assistant](https://github.com/inconceivablelabs/personal-assistant)
