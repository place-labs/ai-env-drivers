# PlaceOS Driver Development Context

run `./setup.sh` once before starting unless explicitly asked not to.

## Company & Project Overview

- You work at Place Technology / PlaceOS - a building automation company
- Use Crystal language to write drivers
- Two main repositories:
  - `drivers/` - Contains another `drivers` folder containing various building automation devices. i.e. `cd drivers && crystal build drivers/message_media/sms.cr`
  - `calendar/` - Contains a standardised interface for cloud based calendaring solutions, with Office365 and Google currently supported
- files in the ./docs folder are mapped to /docs in markitdown.
  - Use the `docs/` folder to store downloaded documents and any markdown outputs from `markitdown`
  - If you have errors converting things to markdown stop and ask what to do differently.
  - for example a file `./docs/protocol.pdf` will be located at `/docs/protocol.pdf` in markitdown build URIs with an empty netloc: `file:///docs/protocol.pdf`
- when compiling and testing drivers, make sure you do so from the correct directory. `drivers/` not `drivers/drivers/`

## Driver Development Resources

- Driver documentation: docs/writing-a-driver.md
- Testing documentation: docs/writing-a-spec.md
- Example drivers (with associated `_spec.cr` files)
  - HTTP: drivers/message_media/sms.cr
  - TCP: drivers/planar/clarity_matrix.cr (good example of using success function correctly)
  - TCP: drivers/embedia/control_point.cr
  - TCP: drivers/shure/microphone/mxa.cr
  - UDP: drivers/extron/usb_extender_plus/endpoint.cr
  - Websocket: drivers/freespace/sensor_api.cr
  - SSH: drivers/extron/matrix.cr (these devices support SSH and telnet)

after running `git submodule update --remote --merge` on the base repository and `shards install` in the drivers folder; you'll see a `lib` folder added to the drivers folder, this has the `placeos-driver` folder in it which is a shard that represents the base class for all drivers. You can also find our standard set of interfaces at `placeos-driver/src/placeos-driver/interface/`

Search the web for additional documentation. Don't create likely structures - all code should be grounded verifiable truth. If you can't the answer for something try asking for help or validation, you are pair programming.

### Development process

#### Plan

1. Understand the task that has been requested.
2. Ask clarifying questions if necessary.
3. Understand the prior art
  - Search the codebase for relevant files
  - Search scratchpads for previous thoughts on the task
4. Think harder about how to break the task down into a series of small, managable tasks:
  - what models are required, if any, to implement the driver
  - does authentication require maintaining
  - what status should be exposed as state (if the device has state, digital twin)
  - what functions should return data (i.e. listing things in service / HTTP drivers)
  - what functionality can be grouped together?
    - Device drivers might have querying state vs changing device state
    - Services / HTTP APIs there might be multiple CRUD endpoints
5. Document your plan in the scratchpad

#### Create and test

1. ensure specs work while the project is small, before adding complexity.
  - Implement some basic functionality and ensure specs run before continuing.
2. Implement a group of functionality and test it before continuing to the next group

## Driver Development Standards

### Structure & Patterns

- Use `require "placeos-driver"` as base
- Inherit from `PlaceOS::Driver`
- Include `descriptive_name` and `generic_name`. A `description` is optional but useful if the docs indicate settings on the device need to be configured or an API key needs to be generated etc. Describe the requirement here.
- Set `udp_port`, `tcp_port` or `uri_base` as appropriate (a TCP port of 22 will assume SSH protocol, the send and received functions represent the text sent to and from the established shell)
- Use `default_settings({})` for configuration
  - NOTE:: device IP and Port details are configured at the platform level. If you need these details for some reason, like if a device uses a different port for some requests, you can grab them from the `config` helper method which returns an object defined in `./drivers/lib/placeos-driver/src/placeos-driver/driver_model.cr`

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

#### HTTP Basic Auth

HTTP service drivers implement basic authentication transparently. Just define your settings like:

```crystal
  default_settings({
    basic_auth: {
      username: "admin",
      password: "admin",
    },
  })
```

as per the example `drivers/message_media/sms.cr` driver and you don't need to explicitly set the `Authorization` header. Still good to check it's sent in the specs.

- Service / HTTP API drivers should automatically authenticate and maintain valid authentication tokens without requiring explicit interaction. i.e. you can provide a `login` for testing, however drivers should lazily call this before executing other requests if there isn't already a valid session.
  - only required if requests can't use basic auth or x-api-keys etc

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
- Test with `should_send()`, `responds()`, `transmit()`, `exec()`, `expect_http_request` (expect_http_request for testing http drivers)
- Use exact protocol examples from device documentation when possible
- Test command flow: `exec(:method)` → `should_send(expected_bytes)` → `responds(response_bytes)` → verify state
  - for http requests flow: `exec(:method)` → `expect_http_request { |request, response| }` → verify state
- only a single `DriverSpecs.mock_driver` in the spec file
- all specs to be contained in the `mock_driver` block
- supports `it "should" do` blocks inside the `mock_driver` block
- does not support `describe Klass do` blocks
- consider timeouts a failure. The `.get` function on `exec` responses in specs is a promise that resolves when the function returns a value. So this is most likely an issue with the command flow where responds or expect_http_request did not provide an appropriate response (or an error in the driver processing the response). These can be tricky to resolve as you may need to consider the current state of the driver and the specs that ran earlier.
- To test `exec` responses using models, re-parse them in the correct type:

```crystal
# check exec response properly using models
future = exec(:function)
# ... perform command flow here: should_send, responds, expect_http_request etc

# parse the output
output = MyModel.from_json(future.get.to_json)
output.field.should eq value
```

### Running Tests

- from the drivers directory
- first format the code specifying the files `crystal tool format drivers/path/to/driver.cr drivers/path/to/driver_spec.cr`
- Use `./harness report drivers/path/to/driver.cr --no-colour --basic-render --verbose` to run the `driver_spec.cr` against the driver
  - ignore `WARN` statements that occur before the test
- Tests must compile and pass before deployment
  - there are 4 types of failure: driver fails to compile, test fails to compile and test doesn't pass, harness failure. Harness will output the details of any failure with backtraces.

A test harness failure will look like a HTTP response error, versus a code backtrace.
If you see something like: `500 Internal Server Error` then this does not represent an issue with the code.

If harness fails you won't be able to run specs, however you should fallback to compiling the driver and spec manually:

- `crystal build drivers/path/to/driver.cr`
- `crystal build drivers/path/to/driver_spec.cr`

need to use `?` accessor for tests checking if a status has been set as it will raise an error if nil without the `?`:

```crystal
channels = status["channels"]?
channels.should_not be_nil
```

When testing status, by preference check the value instead of using `.should_not be_nil` as this will also reveal any potential issues.

### File Organization

- Place drivers in appropriate vendor subdirectory under `drivers/`
- Use snake_case for file names
- Include protocol documentation links in driver comments
- Remove any files you created during the development process that are no longer needed, failed experiments etc.

## Protocol Implementation Guidelines

- Always implement proper message framing and validation
- Include checksum/CRC verification when required by protocol
- Handle escape sequences for binary protocols
- Implement connection management (ping/pong, timeouts)
- Follow exact byte sequences from device documentation where possible. This helps validate correctness.
- Use enums for command constants and states
- Implement proper error handling and NACK / BUSY responses
- Create models that represent the responses and request bodies in JSON APIs
  - use a `{driver_name}_model.cr` file for storing models
  - for json responses use `JSON::Serializable`
    - example: `drivers/juniper/mist_models.cr` or `drivers/lutron/vive_leap_models.cr`
    - don't make all fields optional otheriwse specs may pass without flagging errors
  - for binary protocols, use [BinData](https://github.com/spider-gazelle/bindata) where it makes sense
    - example: `drivers/ashrae/bacnet_models.cr`

Scope models at the manufacturer level. i.e.

```crystal
# file: drivers/manufacturer/product_models.cr
module Manufacturer
  struct ListResponse
    include JSON::Serializable

    # ...
  end
end
```

then we can use `class Manufacturer::Product < PlaceOS::Driver` without scope clashing

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