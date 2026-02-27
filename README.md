# Python Devcontainer Image

Shared development container image for Python projects with Claude Code, Node.js, and common development tools.

## What's Included

- Python 3.12 (Debian Bookworm)
- Node.js 20.x LTS
- Claude Code (native installer)
- Beads task tracking (`bd`) with Dolt backend
- Dolt v1.82.6 (version-controlled SQL database)
- AWS CLI v2
- rbw (unofficial Bitwarden CLI) for secrets management
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

1. Copy the `.devcontainer/` directory from this repo into your project. It includes a reference `devcontainer.json` and `start-dolt.sh` for the Dolt server.

2. Customize `devcontainer.json` for your project (add mounts, env vars, extensions, etc.)

3. Open the project in VS Code and select "Reopen in Container"

The reference config in `.devcontainer/devcontainer.json` includes the minimal setup: the base image, Dolt volume mount, and startup hooks. See the claude-remote workspace for a full example with secrets, SSH keys, and additional volumes.

## How It Works

### Shared vs Project-Specific Data

| Data | Storage | Shared Across Projects? |
|------|---------|------------------------|
| Claude Code settings, hooks, plugins | `~/.claude/` (Docker volume) | Yes |
| MCP servers, OAuth | `~/.claude.json` (bind mount) | Yes |
| Beads tasks (Dolt databases) | `~/.dolt-server/` (Docker volume `dolt-data`) | Yes |
| Beads metadata & JSONL | Project `.beads/` directory | Per project |
| Private journal | `~/.private-journal/` (bind mount) | Yes |
| AWS credentials | `~/.aws/` (Docker volume) | Yes |
| rbw config & vault cache | `~/.config/rbw/` (Docker volume) | Yes |
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

## Dolt Server (Beads Backend)

Beads v0.56+ uses Dolt as its storage backend. A shared Dolt SQL server starts automatically on container startup via `postStartCommand`.

**How it works:**
- Server root: `/home/vscode/.dolt-server/` (persisted in `dolt-data` Docker volume)
- Port: 3307 (localhost)
- Startup script: `.devcontainer/start-dolt.sh` (idempotent, safe to re-run)

**For new projects using Beads:**
```bash
cd your-project
bd init --prefix your-project
```

This creates a `beads_your-project` database on the shared server automatically.

**Manual restart:**
```bash
kill $(cat /home/vscode/.dolt-server/sql-server.pid)
.devcontainer/start-dolt.sh
```

**Logs:** `/home/vscode/.dolt-server/sql-server.log`

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
