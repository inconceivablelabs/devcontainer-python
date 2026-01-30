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

## Usage

In your project's `.devcontainer/devcontainer.json`:

```json
{
  "name": "Python Dev",
  "image": "ghcr.io/inconceivablelabs/devcontainer-python:latest",

  "mounts": [
    "source=${localEnv:HOME}/.secrets/.env,target=/home/vscode/.env,type=bind,readonly",
    "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly",
    "source=python-pip-cache,target=/home/vscode/.cache/pip,type=volume",
    "source=python-dev-aws-config,target=/home/vscode/.aws,type=volume",
    "source=python-dev-claude-config,target=/home/vscode/.claude,type=volume",
    "source=python-dev-bashhistory,target=/home/vscode/.bash_history,type=volume",
    "source=${localEnv:HOME}/.config/claude-shared/.claude.json,target=/home/vscode/.claude.json,type=bind",
    "source=${localEnv:HOME}/.config/claude-shared/.beads,target=/home/vscode/.beads,type=bind",
    "source=${localEnv:HOME}/.config/claude-shared/.private-journal,target=/home/vscode/.private-journal,type=bind"
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
        "python.defaultInterpreterPath": "/usr/local/bin/python"
      },
      "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "charliermarsh.ruff",
        "Anthropic.claude-code"
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

## Updating the Image

Push changes to `main` branch - GitHub Actions will automatically build and push a new image.

To manually trigger a build, use the "Run workflow" button in the Actions tab.

## Pulling Updates

In your project, rebuild the devcontainer to pull the latest image:
- VS Code: `Dev Containers: Rebuild Container`
- CLI: `devcontainer up --remove-existing-container`
