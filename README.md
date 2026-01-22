# erlzeit

NOTE: Archived. This was just an experiment

An Erlang library for timezone-aware timestamps with arithmetics and conversion capabilities.

* Note1: Quality of code: Hacky hack (1-2 days work, and my first Erlang project). 
    There are a lot of unneccessary conversions between different time formats, and the code could be more efficient. 
    But it kind of works, and it's a starting point for further development.
* Note2: This readme is 50% AI generated from the code base, and the AI tends to write in a bit 'braggy' tone ;).

## Features

- **Timezone Support**
  - UTC time handling
  - Local time with automatic DST adjustment
  - Custom UTC offset support
  - Timezone conversion utilities

- **Time Operations**
  - Add/subtract days, hours, minutes, and seconds
  - Support for fractional seconds
  - Calculate time differences with various rounding options
  - Time comparison functions

- **Format Conversions**
  - ISO8601 string formatting and parsing
  - Erlang timestamp conversion
  - Calendar datetime conversion
  - Support for both UTC and local time formats

- **Precision**
  - Microsecond precision support
  - Proper handling of fractional seconds
  - Accurate timezone calculations

## Usage

```erlang
% Create timestamps in different formats
UTC = erlzeit:now(utc)
Local = erlzeit:now(local)
Custom = erlzeit:now({offset, 2})

% Time manipulation
Later = erlzeit:add_days(UTC, 1)
Earlier = erlzeit:add_hours(UTC, -2)
Precise = erlzeit:add_seconds(UTC, 1.5)

% Format conversion
ISOString = erlzeit:to_utc_string(UTC)
Timestamp = erlzeit:from_utc_string("2023-12-31T23:59:59Z")

% Timezone conversion
LocalTime = erlzeit:to_local(UTC)
UTCTime = erlzeit:to_utc(LocalTime)

% Time differences
Seconds = erlzeit:seconds_between_frac(T1, T2) % 1.789
RoundedSeconds = erlzeit:seconds_between_round(T1, T2) % 2
TruncatedSeconds = erlzeit:seconds_between_trunc(T1, T2) % 1
```

## API
```erlang

-export([
    %% erlzeit operations
    now/0,
    now/1,
    add_days/2,
    add_hours/2,
    add_minutes/2,
    add_seconds/2,
    to_utc/1,
    to_local/1,
    seconds_between_round/2,
    seconds_between_trunc/2,
    seconds_between_frac/2,
    %% conversions to/from strings
    to_utc_string/1,
    from_utc_string/1,
    %% conversions to/from erlang builtin types
    to_erlang_timestamp/1,
    from_erlang_timestamp/2,
    to_erlang_calendar_datetime_utc/1,
    to_erlang_calendar_datetime_local/1,
    from_erlang_calendar_datetime_utc/1,
    from_erlang_calendar_datetime_local/1,
    from_erlang_calendar_datetime/2,
    %% utils mostly for testing
    truncate_sec_fraction/1
]).

-export_type([
    type_identifier/0,
    date/0,
    time/0,
    datetime/0,
    offset_hours/0,
    timestamp/0
]).

-type type_identifier() :: utc | local | {offset, offset_hours()}.
-type date() :: {integer(), integer(), integer()}.
-type time() :: {integer(), integer(), float()}.
-type datetime() :: {date(), time()}.
-type offset_hours() :: {offset_hours, integer() | float()}.
-type timestamp() :: {{type, type_identifier()}, {datetime, datetime()}, offset_hours()}.

```

### Erlzeit timestamp format examples

```erlang
{{type,         utc}, {datetime, {{2023, 12, 31}, {21, 59, 59.999999}}, {offset_hours, 0}}}
{{type,       local}, {datetime, {{2023, 12, 31}, {23, 59, 59.999999}}, {offset_hours, 2}}}
{{type, {offset, 2}}, {datetime, {{2023, 12, 31}, {23, 59, 59.999999}}, {offset_hours, 2}}}
```

### DST handling

DST handling is delegated to underlying OS awareness of timezones, through Erlang's builtin `calendar` module.

Example with `erlzeit` from its tests:
```erlang
add_days_local_test() ->
    erlang:display("add_days_local_test"),
    EzTime = erlzeit:now(local),
    EzTime2 = erlzeit:add_days(EzTime, 180),
    EzTime3 = erlzeit:add_days(EzTime2, -180),
    erlang:display(EzTime),
    erlang:display(EzTime2),
    erlang:display(EzTime3),
    ?assertEqual(EzTime, EzTime3).
```
would print (I'm in Sweden)
```erlang
{{type,local},{datetime,{{2025,2,2},{12,45,4.536544e+01}}},{offset_hours,1}}
{{type,local},{datetime,{{2025,8,1},{13,45,4.536544e+01}}},{offset_hours,2}}
{{type,local},{datetime,{{2025,2,2},{12,45,4.536544e+01}}},{offset_hours,1}}
```

## Installation

Add as a dependency in your `rebar.config`:

```erlang
{deps, [
    {erlzeit, {git, "https://github.com/GiGurra/erlzeit.git", {tag, "TBD"}}}
]}.
```

## Dependencies

- iso8601

## Build & Test

```bash
./release.sh
```

This will:
- Compile the project
- Run code formatting
- Run dialyzer
- Execute tests

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
