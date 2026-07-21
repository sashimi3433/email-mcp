# Contributing to Email MCP

Thanks for your interest in contributing! 🎉

## Getting Started

```bash
git clone https://github.com/sashimi3433/email-mcp.git
cd email-mcp
uv sync
```

## Development Setup

### Backend (Python)

```bash
# Install dependencies
uv sync

# Start the Web UI (account management + REST API)
uv run email-mcp-ui

# Start the MCP server (for AI client integration)
uv run email-mcp-server
```

### Flutter App (optional)

```bash
cd app
flutter pub get
flutter run
```

## Project Structure

```
email-mcp/
├── src/email_mcp/          # Python backend
│   ├── server.py           # MCP server (AI tools)
│   ├── web_ui.py           # Flask REST API + Web UI
│   ├── database.py         # SQLite layer
│   ├── imap_client.py      # IMAP fetch logic
│   ├── smtp_client.py      # SMTP send logic
│   ├── sync.py             # Sync orchestration
│   ├── crypto.py           # Password encryption
│   └── config.py           # Configuration
├── app/                    # Flutter management app
│   └── lib/
│       ├── models/         # Data models
│       ├── screens/        # UI screens
│       └── services/       # API client
├── pyproject.toml
└── README.md
```

## Guidelines

### Code Style
- **Python**: Follow PEP 8. Type hints encouraged.
- **Dart**: Run `flutter analyze` before submitting — should pass with zero issues.
- Keep functions focused and well-documented.

### Commit Messages
Use conventional commits:
- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation
- `refactor:` code restructuring
- `chore:` maintenance

### Pull Requests
1. Fork the repo and create a feature branch (`git checkout -b feat/my-feature`)
2. Make your changes
3. Test locally — ensure `flutter analyze` passes and the backend runs
4. Submit a PR with a clear description of what and why

## Reporting Issues

Use [GitHub Issues](https://github.com/sashimi3433/email-mcp/issues) for:
- 🐛 Bug reports (include steps to reproduce)
- ✨ Feature requests
- ❓ Questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
