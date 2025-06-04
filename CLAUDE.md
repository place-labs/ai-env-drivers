# PlaceOS Driver Development Context

## Company & Project Overview
- You work at Place Technology / PlaceOS - a building automation company
- Use Crystal language to write drivers
- Two main repositories:
  - `drivers/` - Contains drivers for various building automation devices
  - `placeos/` - Contains the platform code that drivers run on
  - `calendar/` - Contains a standardised interface for cloud based calendaring solutions, with Office365 and Google currently supported

## Driver Development Resources
- Driver documentation: https://docs.placeos.com/tutorials/backend/write-a-driver
- Testing documentation: https://docs.placeos.com/tutorials/backend/write-a-driver/testing-drivers
- Example drivers:
  - https://github.com/PlaceOS/drivers/blob/master/drivers/message_media/sms.cr
  - https://github.com/PlaceOS/drivers/blob/master/drivers/embedia/control_point.cr

## Driver Development Standards

### Structure & Patterns
- Use `require "placeos-driver"` as base
- Inherit from `PlaceOS::Driver`
- Include `descriptive_name` and `generic_name`
- Set `tcp_port` or `uri_base` as appropriate
- Use `default_settings({})` for configuration

### State Management
- Expose state using `self[:state_name] = "value"`
- Use indexed state for multiple items: `self["outlet_#{index}"] = state`
- State creates digital twin functionality

### Method Patterns
- `on_load` - initialize transport, tokenizer, call `on_update`
- `on_update` - read settings and update instance variables
- `connected` - schedule periodic tasks
- `disconnected` - clear schedules
- `received(data, task)` - handle incoming data, call `task.try &.success`

### Communication
- Use `send(data, **options)` to transmit
- Use `transport.tokenizer` for message framing
- Handle protocol-specific encoding/escaping

### Testing
- Create `*_spec.cr` files alongside drivers
- Use `DriverSpecs.mock_driver "ClassName" do ... end`
- Test with `should_send()`, `responds()`, `transmit()`, `exec()`
- Use exact protocol examples from device documentation when possible
- Test command flow: `exec(:method)` → `should_send(expected_bytes)` → `responds(response_bytes)` → verify state

### Running Tests
- Use `./harness report drivers/path/to/driver.cr` from drivers directory
- Tests must compile and pass before deployment

### File Organization
- Place drivers in appropriate vendor subdirectory under `drivers/`
- Use snake_case for file names
- Include protocol documentation links in driver comments

## Protocol Implementation Guidelines
- Always implement proper message framing and validation
- Include checksum/CRC verification when required by protocol
- Handle escape sequences for binary protocols
- Implement connection management (ping/pong, timeouts)
- Follow exact byte sequences from device documentation
- Use enums for command constants and states
- Implement proper error handling and NACK responses

## Common Device Types
- Power controllers (outlets, sequencing, EPO)
- Display controllers
- Audio/video switchers
- Lighting controllers
- Sensor interfaces
- Security systems
- HVAC controllers

## Tool Permissions & Access
The following resources are typically needed for driver development:
- Access to PlaceOS documentation at docs.placeos.com
- Access to Crystal Lang documentation at crystal-lang.org/reference/latest/ and crystal-lang.org/api/latest
- Access to device documentation (often PDFs hosted on cloudinary)
- Crystal language tools and compilation
- Docker for running test harness and MCP servers
- File system operations for creating/editing drivers
- Bash commands for running harness and build tools
- Web fetch capabilities for accessing protocol documentation