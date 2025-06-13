# PlaceOS AI Driver Development Environment

This repository provides a complete development environment for PlaceOS drivers with AI assistance through Claude Code.

## Installation

### 1. Clone Repository with Submodules

If you haven't cloned this repository yet:

```shell
git clone https://github.com/PlaceOS/ai-env-drivers.git
cd ai-env-drivers
```

### 2. Setup Claude Code

Make sure `npm` is installed, you can use [nvm](https://github.com/nvm-sh/nvm?tab=readme-ov-file#installing-and-updating)

```shell
nvm use node
npm config set os linux
npm install -g @anthropic-ai/claude-code --force --no-os-check
```

1. Install Claude Code following the instructions at [docs.anthropic.com/claude-code](https://docs.anthropic.com/en/docs/claude-code/overview)
2. Get your API key from Bitwarden (search for "Claude API")
3. Configure Claude Code with your API key

## Usage

1. Navigate to the ai-env-drivers directory:
   ```bash
   cd ai-env-drivers
   ```

2. Start Claude Code:
   ```bash
   claude --mcp-config ./claude_desktop_config.json
   ```

3. Tell Claude what driver you want to develop, including:
   - Device manufacturer and model
   - Communication protocol (TCP, UDP, Serial, HTTP)
   - Links to device documentation (PDFs, protocol specs, etc.)
   - Any specific functionality requirements

### Example Usage

```
I need to develop a driver for the Acme Display Controller Model X100. 
It uses TCP communication on port 23 with a simple ASCII protocol.
Here's the protocol documentation: https://example.com/docs/x100-protocol.pdf
I need to control power, input selection, and volume.
```

Claude will:
- Read and analyze the device documentation
- Create the driver following PlaceOS conventions
- Write comprehensive tests
- Ensure proper protocol implementation

## Repository Structure

- `drivers/` - PlaceOS drivers repository (submodule)
- `calendar/` - Calendar service drivers (submodule)
- `markitdown/` - PDF documentation reader (submodule)
- `CLAUDE.md` - Development context and guidelines for Claude

## Resources

- [PlaceOS Driver Documentation](https://docs.placeos.com/tutorials/backend/write-a-driver)
- [Testing Documentation](https://docs.placeos.com/tutorials/backend/write-a-driver/testing-drivers)
- [Crystal Lang Book](https://crystal-lang.org/reference/latest/)
- [Crystal Lang API Reference](https://crystal-lang.org/api/latest/)
