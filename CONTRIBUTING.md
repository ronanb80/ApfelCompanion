# Contributing to Apfel Companion

## Prerequisites

- **Xcode** (latest version)
- **Homebrew**: https://brew.sh
- **apfel**: `brew install apfel`
- **SwiftLint**: `brew install swiftlint`
- **GitHub CLI** (for releases): `brew install gh`

## Development Workflow

### Building

Open `ApfelCompanion.xcodeproj` in Xcode and build with `Cmd+B`, or from the terminal:

```bash
make build
```

### Running

Run the app from Xcode with `Cmd+R`. The app will automatically start an `apfel` server on port 11438. If apfel is already running (e.g. from your terminal), the app will connect to the existing instance.

### Linting

SwiftLint is used for code linting. Run it locally:

```bash
make lint
```

SwiftLint also runs automatically on every push/PR via GitHub Actions (on a free Linux runner to conserve macOS minutes). Configuration is in `.swiftlint.yml`.

### Testing

```bash
make test
```

### Available Make Commands

| Command | Description |
|---------|-------------|
| `make build` | Build the project |
| `make test` | Run unit tests |
| `make lint` | Run SwiftLint |
| `make clean` | Remove build artifacts |
| `make archive` | Create a release archive |
| `make release VERSION=x.y.z` | Build, archive, zip, and create a GitHub release |

## CI/CD

### What runs in CI (GitHub Actions)

- **SwiftLint** on every push/PR — runs on an Ubuntu runner (free tier friendly)

### What runs locally

- **Build, test, and release** — run on your Mac since GitHub's free tier macOS minutes are limited (200 effective minutes/month)

### Creating a Release

1. Make sure all changes are committed and pushed
2. Run: `make release VERSION=1.0.0`
3. This will:
   - Clean previous builds
   - Archive the app
   - Export and zip `ApfelCompanion.app`
   - Create a GitHub release with the zip attached

> **Note:** You'll need an `ExportOptions.plist` for the archive export. Xcode generates one when you manually archive and export for the first time via Organizer.

## Architecture

The app follows a straightforward MVVM pattern:

- **ApfelService** manages the `apfel` CLI process — finding the binary, launching the server, health-checking, and terminating on shutdown
- **ChatClient** handles HTTP communication with apfel's OpenAI-compatible API, including SSE streaming for real-time token delivery
- **ChatViewModel** is an `@Observable` class that ties the service and client together, managing message state and generation lifecycle
- **Views** are pure SwiftUI, driven by the view model

## App Sandbox

The App Sandbox is **disabled** because the app needs to spawn the `apfel` subprocess. This is fine for Homebrew distribution but means the app cannot be published to the Mac App Store.
