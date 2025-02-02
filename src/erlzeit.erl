-module(erlzeit).

%% ====================================================================
%% PUBLIC API
%% ====================================================================

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

-spec now(type_identifier()) -> timestamp().
now(utc) ->
    from_erlang_timestamp(erlang:timestamp(), {type, utc});
now(local) ->
    from_erlang_timestamp(
        erlang:timestamp(), {type, local}
    );
now({offset, OffsetHours}) ->
    from_erlang_timestamp(erlang:timestamp(), {type, {offset, OffsetHours}}).

-spec now() -> timestamp().
now() -> now(utc).

to_erlang_timestamp({
    {type, _},
    {datetime, {{Year, Month, Day}, {Hour, Minute, Second}}},
    {offset_hours, OffsetHours}
}) ->
    MicroSecPart = round((Second - trunc(Second)) * 1000000),
    GregSecs =
        calendar:datetime_to_gregorian_seconds({{Year, Month, Day}, {Hour, Minute, trunc(Second)}}) -
            OffsetHours * 3600 - erltime_gregsec_diff_seconds(),
    MegSecs = trunc(GregSecs / 1000000),
    Secs = GregSecs - MegSecs * 1000000,
    {MegSecs, Secs, MicroSecPart}.

from_erlang_timestamp(
    {MegSecs, Secs, MicroSecs},
    {type, utc}
) ->
    {{Year, Month, Day}, {Hour, Minute, Second}} = calendar:now_to_universal_time(
        {MegSecs, Secs, 0}
    ),
    SecFracPart =
        case MicroSecs of
            MicroSecs when abs(MicroSecs) >= 1 ->
                MicroSecs / 1000000;
            _ ->
                0
        end,
    {
        {type, utc},
        {datetime, {{Year, Month, Day}, {Hour, Minute, Second + SecFracPart}}},
        {offset_hours, 0}
    };
from_erlang_timestamp(
    {MegSecs, Secs, MicroSecs},
    {type, TypeID}
) ->
    OffsetHours =
        case TypeID of
            local -> get_local_offset_hours({MegSecs, Secs, 0});
            {offset, Offset} -> Offset
        end,
    {{Year, Month, Day}, {Hour, Minute, Second}} =
        calendar:gregorian_seconds_to_datetime(
            calendar:datetime_to_gregorian_seconds(
                calendar:now_to_universal_time({MegSecs, Secs, 0})
            ) + OffsetHours * 3600
        ),
    SecFracPart =
        case MicroSecs of
            MicroSecs when abs(MicroSecs) >= 1 ->
                MicroSecs / 1000000;
            _ ->
                0
        end,
    {
        {type, TypeID},
        {datetime, {{Year, Month, Day}, {Hour, Minute, Second + SecFracPart}}},
        {offset_hours, OffsetHours}
    };
from_erlang_timestamp(
    {MegSecs, Secs, MicroSecs},
    TypeID
) ->
    from_erlang_timestamp({MegSecs, Secs, MicroSecs}, {type, TypeID}).

to_utc_string(
    Timestamp = {
        {type, _},
        {datetime, {{_, _, _}, {_, _, _}}},
        {offset_hours, _}
    }
) ->
    AtUtc = to_utc(Timestamp),
    iso8601:format(datetime_part(AtUtc)).

to_utc(
    {
        {type, _},
        {datetime, DateTime},
        {offset_hours, 0}
    }
) ->
    {
        {type, utc},
        {datetime, DateTime},
        {offset_hours, 0}
    };
to_utc(
    {
        {type, _},
        {datetime, {_, _}},
        {offset_hours, OffsetHours}
    } = Timestamp
) ->
    tz_change(Timestamp, -OffsetHours).

to_local(
    {
        {type, local},
        {datetime, _},
        {offset_hours, _}
    } = Timestamp
) ->
    Timestamp;
to_local(
    {
        {type, _},
        {datetime, {_, _}},
        {offset_hours, _}
    } = Timestamp
) ->
    ErlangTimestamp = to_erlang_timestamp(Timestamp),
    from_erlang_timestamp(ErlangTimestamp, local).

seconds_between_round(T1, T2) ->
    round(seconds_between_frac(T1, T2)).

seconds_between_trunc(T1, T2) ->
    trunc(seconds_between_frac(T1, T2)).

seconds_between_frac(T1, T2) ->
    {MegSecs1, Secs1, MicroSecs1} = to_erlang_timestamp(T1),
    {MegSecs2, Secs2, MicroSecs2} = to_erlang_timestamp(T2),
    (MegSecs2 - MegSecs1) * 1000000 + ((Secs2 - Secs1) + (MicroSecs2 - MicroSecs1) / 1000000).

from_utc_string(String) ->
    CalDateTime = iso8601:parse_exact(String),
    {
        {type, utc},
        {datetime, CalDateTime},
        {offset_hours, 0}
    }.

add_days(
    {
        {type, _} = Type,
        {datetime, {_, _}},
        {offset_hours, _}
    } = Timestamp,
    Days
) ->
    % Needs to be done in utc, as dst etc may change from date to date
    {TimestampNoSec, Sfr} = without_sec(Timestamp),
    TimestampUTCNoSec = tz_change_to_utc(TimestampNoSec),
    NewDatetimePartNoSec = iso8601:add_days(datetime_part(TimestampUTCNoSec), Days),
    with_sec(
        from_erlang_timestamp(
            to_erlang_timestamp({{type, utc}, {datetime, NewDatetimePartNoSec}, {offset_hours, 0}}),
            Type
        ),
        Sfr
    ).

add_hours(
    {
        {type, _} = Type,
        {datetime, {_, _}},
        {offset_hours, _}
    } = Timestamp,
    Hours
) ->
    % Needs to be done in utc, as dst etc may change from date to date
    {TimestampNoSec, Sfr} = without_sec(Timestamp),
    TimestampUTCNoSec = tz_change_to_utc(TimestampNoSec),
    NewDatetimePartNoSec = iso8601:add_time(datetime_part(TimestampUTCNoSec), Hours, 0, 0),
    with_sec(
        from_erlang_timestamp(
            to_erlang_timestamp({{type, utc}, {datetime, NewDatetimePartNoSec}, {offset_hours, 0}}),
            Type
        ),
        Sfr
    ).

add_minutes(
    {
        {type, _} = Type,
        {datetime, {_, _}},
        {offset_hours, _}
    } = Timestamp,
    Minutes
) ->
    % Needs to be done in utc, as dst etc may change from date to date
    {TimestampNoSec, Sfr} = without_sec(Timestamp),
    TimestampUTCNoSec = tz_change_to_utc(TimestampNoSec),
    NewDatetimePartNoSec = iso8601:add_time(datetime_part(TimestampUTCNoSec), 0, Minutes, 0),
    with_sec(
        from_erlang_timestamp(
            to_erlang_timestamp({{type, utc}, {datetime, NewDatetimePartNoSec}, {offset_hours, 0}}),
            Type
        ),
        Sfr
    ).

add_seconds(
    {
        {type, _} = Type,
        {datetime, {_, _}},
        {offset_hours, _}
    } = Timestamp,
    Seconds
) ->
    % We need to add the orig seconds with Seconds, then extract
    % the fractional part and handle it separately
    {TimestampNoSec, OrigSeconds} = without_sec(Timestamp),
    %% Now add all seconds together
    NewSeconds = OrigSeconds + Seconds,
    %% Extract the fractional part
    WholeSec = trunc_down(NewSeconds),
    Sfr = truncate_frac_to_microsec(NewSeconds - WholeSec),
    TimestampUTCNoSec = tz_change_to_utc(TimestampNoSec),
    NewDatetimePartNoSec = iso8601:add_time(datetime_part(TimestampUTCNoSec), 0, 0, WholeSec),
    with_sec_frac(
        from_erlang_timestamp(
            to_erlang_timestamp({{type, utc}, {datetime, NewDatetimePartNoSec}, {offset_hours, 0}}),
            Type
        ),
        Sfr
    ).

trunc_down(Frac) ->
    case Frac of
        _ when Frac >= 0 -> trunc(Frac);
        _ -> trunc(Frac) - 1
    end.

truncate_frac_to_microsec(Frac) ->
    case Frac * 1000000 of
        F when abs(F) >= 1 -> Frac;
        _ -> 0
    end.

to_erlang_calendar_datetime_utc(
    {
        {type, _},
        {datetime, _},
        {offset_hours, _}
    } = Timestamp
) ->
    UtcTimestamp = tz_change_to_utc(Timestamp),
    datetime_part(UtcTimestamp).

to_erlang_calendar_datetime_local(
    {
        {type, _},
        {datetime, _},
        {offset_hours, _}
    } = Timestamp
) ->
    ErlangTimestamp = to_erlang_timestamp(Timestamp),
    LocalEzTimestamp = from_erlang_timestamp(ErlangTimestamp, local),
    datetime_part(LocalEzTimestamp).

from_erlang_calendar_datetime_utc(CalDateTimeUTC) ->
    {
        {type, utc},
        {datetime, CalDateTimeUTC},
        {offset_hours, 0}
    }.

from_erlang_calendar_datetime_local(CalDateTimeUTC) ->
    from_erlang_calendar_datetime(CalDateTimeUTC, local).

from_erlang_calendar_datetime({{YY, MM, DD}, {H, M, Sfr}}, Type) ->
    DTInNoSec = {{YY, MM, DD}, {H, M, 0}},
    DTUTCNoSec =
        case Type of
            utc ->
                DTInNoSec;
            local ->
                case calendar:local_time_to_universal_time_dst(DTInNoSec) of
                    [Res] -> Res;
                    [Res, _] -> Res
                end;
            {offset, Offset} ->
                datetime_part(
                    tz_change(
                        {
                            {type, {offset, Offset}},
                            {datetime, DTInNoSec},
                            {offset_hours, Offset}
                        },
                        -Offset
                    )
                )
        end,
    ResNoTZNoSec = from_erlang_calendar_datetime_utc(DTUTCNoSec),
    ErlTzNoSec = to_erlang_timestamp(ResNoTZNoSec),
    EztimeNoSec = from_erlang_timestamp(ErlTzNoSec, Type),
    with_sec(EztimeNoSec, Sfr).

truncate_sec_fraction(
    {
        Type,
        {datetime, {{YY, MM, DD}, {H, M, S}}},
        Offset
    }
) ->
    {
        Type,
        {datetime, {{YY, MM, DD}, {H, M, trunc(S)}}},
        Offset
    };
truncate_sec_fraction({{YY, MM, DD}, {H, M, S}}) ->
    {{YY, MM, DD}, {H, M, trunc(S)}};
truncate_sec_fraction({MegSecs, Secs, _}) ->
    {MegSecs, Secs, 0}.

%% ====================================================================
%% INTERNAL HELPERS
%% ====================================================================

without_sec(
    {
        Type,
        {datetime, {{YY, MM, DD}, {H, M, Sfr}}},
        Offset
    }
) ->
    {
        {
            Type,
            {datetime, {{YY, MM, DD}, {H, M, 0}}},
            Offset
        },
        Sfr
    }.

with_sec(
    {
        Type,
        {datetime, {{YY, MM, DD}, {H, M, _}}},
        Offset
    },
    Sfr
) ->
    {
        Type,
        {datetime, {{YY, MM, DD}, {H, M, Sfr}}},
        Offset
    }.

with_sec_frac(
    {
        Type,
        {datetime, {{YY, MM, DD}, {H, M, S}}},
        Offset
    },
    Sfr
) ->
    {
        Type,
        {datetime, {{YY, MM, DD}, {H, M, S + Sfr}}},
        Offset
    }.

datetime_part(
    {
        {type, _},
        {datetime, DT},
        {offset_hours, _}
    }
) ->
    DT.

tz_change_to_utc(
    {
        {type, utc},
        {datetime, _},
        {offset_hours, _}
    } = TZ
) ->
    TZ;
tz_change_to_utc(
    {
        {type, _},
        {datetime, _},
        {offset_hours, OriginalOffsetHours}
    } = TZ
) ->
    tz_change(
        TZ,
        -OriginalOffsetHours
    ).

tz_change(
    Orig = {
        {type, _},
        {datetime, {_, {_, _, OrigSec}}},
        {offset_hours, OriginalOffsetHours}
    },
    DeltaHours
) ->
    {{Year, Month, Day}, {Hour, Minute, Second}} =
        calendar:gregorian_seconds_to_datetime(
            calendar:datetime_to_gregorian_seconds(
                datetime_part(truncate_sec_fraction(Orig))
            ) + DeltaHours * 3600
        ),
    NewOffsetHours = OriginalOffsetHours + DeltaHours,
    Type =
        case NewOffsetHours of
            0 -> utc;
            _ -> {offset, NewOffsetHours}
        end,
    MicroSecs = (OrigSec - trunc(OrigSec)) * 1000000,
    SecFracPart =
        case MicroSecs of
            MicroSecs when abs(MicroSecs) >= 1 ->
                MicroSecs / 1000000;
            _ ->
                0
        end,
    {
        {type, Type},
        {datetime, {{Year, Month, Day}, {Hour, Minute, Second + SecFracPart}}},
        {offset_hours, NewOffsetHours}
    }.

get_local_offset_hours(ErlTime = {_, _, _}) ->
    case {calendar:now_to_local_time(ErlTime), calendar:now_to_universal_time(ErlTime)} of
        {LocalTime, UniversalTime} ->
            diff_in_hours(LocalTime, UniversalTime)
    end.

erltime_gregsec_diff_seconds() ->
    ErlTime = {ErlMegSec, ErlSec, _} = erlang:timestamp(),
    ErlSecs = ErlMegSec * 1000000 + ErlSec,
    ErlGregSec = calendar:datetime_to_gregorian_seconds(calendar:now_to_universal_time(ErlTime)),
    ErlGregSec - ErlSecs.

diff_in_hours(LocalTime, UniversalTime) ->
    LocalSeconds = calendar:datetime_to_gregorian_seconds(LocalTime),
    UtcSeconds = calendar:datetime_to_gregorian_seconds(UniversalTime),
    (LocalSeconds - UtcSeconds) div 3600.
