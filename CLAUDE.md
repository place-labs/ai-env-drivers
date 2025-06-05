# PlaceOS Driver Development Context

## Company & Project Overview

- You work at Place Technology / PlaceOS - a building automation company
- Use Crystal language to write drivers
- Two main repositories:
  - `drivers/` - Contains drivers for various building automation devices
  - `calendar/` - Contains a standardised interface for cloud based calendaring solutions, with Office365 and Google currently supported
- use the `docs/` folder to store downloaded documents and any markdown outputs from `markitdown`

## Driver Development Resources

- Driver documentation: https://docs.placeos.com/tutorials/backend/write-a-driver
- Testing documentation: https://docs.placeos.com/tutorials/backend/write-a-driver/testing-drivers
- Example drivers (with associated `_spec.cr` files)
  - HTTP: drivers/message_media/sms.cr
  - TCP: drivers/planar/clarity_matrix.cr (good example of using success function correctly)
  - TCP: drivers/embedia/control_point.cr
  - TCP: drivers/shure/microphone/mxa.cr
  - UDP: drivers/extron/usb_extender_plus/endpoint.cr
  - Websocket: drivers/freespace/sensor_api.cr
  - SSH: drivers/extron/matrix.cr (these devices support SSH and telnet)

after running `git submodule update --remote --merge` on the base repository and `shards install` in the drivers folder; you'll see a `lib` folder added to the drivers folder, this has the `placeos-driver` folder in it which is a shard that represents the base class for all drivers. You can also find our standard set of interfaces at `placeos-driver/src/placeos-driver/interface/`

## Driver Development Standards

### Structure & Patterns

- Use `require "placeos-driver"` as base
- Inherit from `PlaceOS::Driver`
- Include `descriptive_name` and `generic_name`. A `description` is optional but useful if the docs indicate settings on the device need to be configured or an API key needs to be generated etc. Describe the requirement here.
- Set `udp_port`, `tcp_port` or `uri_base` as appropriate (a TCP port of 22 will assume SSH protocol, the send and received functions represent the text sent to and from the established shell)
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
- `received(data, task)` - handle incoming data. The task object is only set (otherwise is `nil`) if we are expecting a response from the device for a recent `send` made by us.
- If the task object is set, the `received` function should indicate if this response is related to the request (often devices can push data without a request being made)
  - if the data is not a response to the task, process the data, ignoring the task object
  - if there is an error response call `task.try(&.abort("optional reason for abort"))` on the task
  - if there is a busy response, can call `task.try(&.retry("optional reason for retry")` - if a pause is desirable, so the device is less busy, can set a wait on the task before calling retry `task.wait = 100.milliseconds`
  - if the response is a success, after updating any relavent state, call `task.try(&.success(optional_result_object))` - the result object is useful where querying state (versus requesting an action) and a value representing the state queried can be passed. This is because the task object works like a promise or future.

### Communication

- Use `send(data, **options)` to transmit
- Use `transport.tokenizer` for message framing
- Handle protocol-specific encoding/escaping
- HTTP based APIs use method helpers, such as `get`, `post` etc. Similar interface to the crystal HTTP::Client class.

For stream based protocols (such as UDP, TCP, SSH, Websocket) the send method transparently queues requests so they are not sent concurrently as most devices can't handle this.

The queue supports named commands, which can prevent commands building up. i.e. if a user controlling a LCD Display was to request switching to VGA, DVI, DisplayPort and then HDMI, we might have already started processing the request to switch to VGA but then we can switch straight to HDMI without running through all the other inputs requested. Ideally most commands that perform an action should be named, whereas status query commands should not be named as they don't effect device state.

Using named commands: `send(data, name: "volume")`

If we're not expecting a response for a send, i.e. the device sent us a `ping` and we need to reply with a `pong` then use `send(data, wait: false)` - don't wait for a response.
Where we're never expecting the device to acknowlege requests you can set `queue.wait = false` in the `on_load` function.

It's also a priority queue, this ensure some actions take priority. 0 is a low priority, 100 is a high priority, default tasks have a priority of 50 and tasks being retried get a bonus priority of 20 (so they run before the next task)
`send(data, priority: 99)`
An example where priority is required might be a stop command. i.e. a camera is panning left, the device is being queried for state and we want to stop before processing state queries. If we don't prioritise the task it will appear like there is latency in the task and we want to be as close to real-time as possible.
This does mean that there could be some conflicting tasks in the queue (i.e. pan-down) as this has jumped ahead. You can also clear the queue when a task is run by `send(data, priority: 99, clear_queue: true)`

Wait before sending or delaying the next task or additional retries (the default is 3 retries) are required, these can be added where needed. i.e. 
`send(data, wait: 100.milliseconds, delay: 50.milliseconds, retries: 8)`

By default the queue has a timeout of 5 seconds. That is, if abort or success is not called within 5 seconds the request will automatically be retried, resent.
The timeout can be configured: `send(data, timeout: 5.seconds)`

All the send options can be set directly on the `queue` object in the `on_load` function.

#### Tokenization

The received function should only process one message at a time. This means binary streams need to be split up into the individual messages using the tokenizer. Not relevant for API / HTTP services.

- Terminating bytes: `transport.tokenizer = Tokenizer.new("\r\n")` or `Tokenizer.new(Bytes[0x03])`
- Header with constant length message: `transport.tokenizer = Tokenizer.new(4, "HEADER")` or `Tokenizer.new(4)`

A length in the header:
Let's assume a simple protocol like `0x02<len><payload><checksum>0x03`
The total message length is the length of the `payload` section + 4 bytes representing the other sections.

```crystal
# setting in connected ensures the buffer is cleared
# if the device disconnects mid message
def connected
  # return the size of the message or -1 if there are not enough bytes
  transport.tokenizer = Tokenizer.new do |io|
    bytes = io.to_slice

    next -1 if bytes.size < 2

    expected = 4 + bytes[1].to_i
    bytes.size >= expected ? expected : -1
  end
end
```

alternatively you could attempt to parse a header of a more complex protocol. For our KNX driver which has parsing for KNX protocol data structures - tools like https://github.com/spider-gazelle/bindata can help implement complex protocols like this.

```crystal
def connected
  transport.tokenizer = Tokenizer.new do |io|
    bytes = io.peek

    # make sure we can parse the header
    next 0 unless bytes.size > 5

    # extract the request length
    io = IO::Memory.new(bytes)
    header = io.read_bytes(KNX::Header)
    header.request_length.to_i
  end
end
```

There is additional documentation here: https://github.com/spider-gazelle/tokenizer

### Testing

- Create `*_spec.cr` files alongside drivers
- Use `DriverSpecs.mock_driver "ClassName" do ... end`
- Test with `should_send()`, `responds()`, `transmit()`, `exec()`
- Use exact protocol examples from device documentation when possible
- Test command flow: `exec(:method)` → `should_send(expected_bytes)` → `responds(response_bytes)` → verify state

### Running Tests

- from the drivers directory
- first format the code specifying the files `crystal tool format drivers/path/to/driver.cr drivers/path/to/driver_spec.cr`
- Use `./harness report drivers/path/to/driver.cr --no-colour --basic-render --verbose` to run the `driver_spec.cr` against the driver
  - ignore `WARN` statements that occur before the test
- Tests must compile and pass before deployment
  - there are 3 types of failure: driver fails to compile, test fails to compile and test doesn't pass. Harness will output the details of any failure with backtraces.

### File Organization

- Place drivers in appropriate vendor subdirectory under `drivers/`
- Use snake_case for file names
- Include protocol documentation links in driver comments

## Protocol Implementation Guidelines

- Always implement proper message framing and validation
- Include checksum/CRC verification when required by protocol
- Handle escape sequences for binary protocols
- Implement connection management (ping/pong, timeouts)
- Follow exact byte sequences from device documentation where possible. This helps validate correctness.
- Use enums for command constants and states
- Implement proper error handling and NACK / BUSY responses

## Common Device Types

- Power controllers
- Display controllers
- Audio/video switchers
- Lighting controllers
- Sensor interfaces
- Security systems
- HVAC controllers

Make sure to implement interfaces where possible.
This allows the platform to interact generically.

i.e. a logic module could request all devices in a system to power off using the powerable interface: `system.implementing(Interface::Powerable).power false`

## Tool Permissions & Access

The following resources are typically needed for driver development:
- Access to PlaceOS documentation at docs.placeos.com
- Access to Crystal Lang documentation at crystal-lang.org/reference/latest/ and crystal-lang.org/api/latest
- Access to device documentation PDFs, word docs, excel etc
- Crystal language tools and compilation
- Docker for running test harness and MCP servers
- File system operations for creating/editing drivers
- Bash commands for running harness and build tools
- Web fetch capabilities for accessing protocol documentation