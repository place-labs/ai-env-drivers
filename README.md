# PlaceOS AI Driver Development Environment

This repository provides a complete development environment for PlaceOS drivers with AI assistance through Claude Code.

## Setup Claude Code

Make sure `npm` is installed, you can use [nvm](https://github.com/nvm-sh/nvm?tab=readme-ov-file#installing-and-updating)

```shell
nvm use node
npm config set os linux
npm install -g @anthropic-ai/claude-code --force --no-os-check
```

You'll require an account with access to Claude Code [docs.anthropic.com/claude-code](https://docs.anthropic.com/en/docs/claude-code/overview)

## Usage

1. Clone this repository:
   ```shell
   git clone https://github.com/PlaceOS/ai-env-drivers.git
   cd ai-env-drivers
   ```

2. Run setup to ensure we're ready for the AI
   ```shell
   ./setup.sh
   ```

3. Start Claude Code:
   ```shell
   claude --mcp-config ./claude_desktop_config.json
   ```

4. Tell Claude what driver you want to develop, including:
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

- `drivers/` - PlaceOS drivers repository
- `calendar/` - Calendar service drivers (submodule)
- `markitdown/` - PDF documentation reader (submodule)
- `CLAUDE.md` - Development context and guidelines for Claude

## Resources

- [PlaceOS Driver Documentation](https://docs.placeos.com/tutorials/backend/write-a-driver)
- [Testing Documentation](https://docs.placeos.com/tutorials/backend/write-a-driver/testing-drivers)
- [Crystal Lang Book](https://crystal-lang.org/reference/latest/)
- [Crystal Lang API Reference](https://crystal-lang.org/api/latest/)
