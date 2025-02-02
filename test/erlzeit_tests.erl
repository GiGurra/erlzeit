-module(erlzeit_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/logger.hrl").

utc_test() ->
    CurrenTime0 = {{type, utc}, {datetime, _}, {offset_hours, 0}} = erlzeit:now(),
    CurrenTime1 = {{type, utc}, {datetime, _}, {offset_hours, 0}} = erlzeit:now(utc),
    erlang:display(CurrenTime0),
    erlang:display(CurrenTime1),
    ?LOG_INFO("Current time: ~p", [CurrenTime0]),
    ?LOG_INFO("Current time: ~p", [CurrenTime1]).

local_test() ->
    CurrenTime = {{type, local}, {datetime, _}, {offset_hours, _}} = erlzeit:now(local),
    erlang:display(CurrenTime),
    ?LOG_INFO("Current time: ~p", [CurrenTime]).

offset_test() ->
    CurrenTime = {{type, {offset, 2}}, {datetime, _}, {offset_hours, 2}} = erlzeit:now({offset, 2}),
    erlang:display(CurrenTime),
    ?LOG_INFO("Current time: ~p", [CurrenTime]).

to_from_erlang_timestamp_utc_test() ->
    EzTime = erlzeit:now(utc),
    ErlangTime = erlzeit:to_erlang_timestamp(EzTime),
    EzTimeBack = erlzeit:from_erlang_timestamp(ErlangTime, utc),
    ?assertEqual(EzTime, EzTimeBack).

to_from_erlang_timestamp_local_test() ->
    EzTime = erlzeit:now(local),
    ErlangTime = erlzeit:to_erlang_timestamp(EzTime),
    EzTimeBack = erlzeit:from_erlang_timestamp(ErlangTime, local),
    ?assertEqual(EzTime, EzTimeBack).

to_from_utc_string_test() ->
    EzTime = erlzeit:now(utc),
    EzString = erlzeit:to_utc_string(EzTime),
    erlang:display(EzString),
    ?LOG_INFO("Current time: ~p", [EzString]),
    ParsedBack = erlzeit:from_utc_string(EzString),
    ?assertEqual(EzTime, ParsedBack).

add_days_utc_test() ->
    EzTime = erlzeit:now(utc),
    EzTime2 = erlzeit:add_days(EzTime, 1),
    EzTime3 = erlzeit:add_days(EzTime2, -1),
    erlang:display(EzTime),
    erlang:display(EzTime2),
    erlang:display(EzTime3),
    ?assertEqual(EzTime, EzTime3).

add_days_local_test() ->
    erlang:display("add_days_local_test"),
    EzTime = erlzeit:now(local),
    EzTime2 = erlzeit:add_days(EzTime, 180),
    EzTime3 = erlzeit:add_days(EzTime2, -180),
    erlang:display(EzTime),
    erlang:display(EzTime2),
    erlang:display(EzTime3),
    ?assertEqual(EzTime, EzTime3).

add_hours_utc_test() ->
    EzTime = erlzeit:now(utc),
    EzTime2 = erlzeit:add_hours(EzTime, 1),
    EzTime3 = erlzeit:add_hours(EzTime2, -1),
    erlang:display(EzTime),
    erlang:display(EzTime2),
    erlang:display(EzTime3),
    ?assertEqual(EzTime, EzTime3).

to_calendar_datetime_utc_test() ->
    EzTime = erlzeit:now(utc),
    EzTime2 = erlzeit:to_erlang_calendar_datetime_utc(EzTime),
    EzTime3 = erlzeit:from_erlang_calendar_datetime_utc(EzTime2),
    erlang:display(EzTime),
    erlang:display(EzTime2),
    erlang:display(EzTime3),
    ?assertEqual(EzTime, EzTime3).

from_erlang_calendar_datetime_x_test() ->
    ErlTime = calendar:now_to_datetime(erlang:timestamp()),
    EzTime = erlzeit:from_erlang_calendar_datetime_utc(ErlTime),
    ErlTime2 = iso8601:add_time(ErlTime, 1, 0, 0),
    EzTime3 = erlzeit:from_erlang_calendar_datetime(ErlTime2, {offset, 1}),
    EzTime4 = erlzeit:to_utc(EzTime3),
    ?assertEqual(EzTime, EzTime4).

from_erlang_calendar_datetime_local_test() ->
    ErlTimestamp = erlang:timestamp(),
    ErlLocalTime = calendar:now_to_local_time(ErlTimestamp),
    ErlUtcTime = calendar:now_to_datetime(ErlTimestamp),
    EzLocal = erlzeit:from_erlang_calendar_datetime_local(ErlLocalTime),
    EzUtc = erlzeit:from_erlang_calendar_datetime_utc(ErlUtcTime),
    EzLocal2 = erlzeit:to_local(EzUtc),
    EzUtc2 = erlzeit:to_utc(EzLocal),
    ?assertEqual(EzLocal, EzLocal2),
    ?assertEqual(EzUtc, EzUtc2).

to_erlang_calendar_datetime_local_test() ->
    erlang:display("to_erlang_calendar_datetime_local_test"),
    EzTime = erlzeit:truncate_sec_fraction(erlzeit:now(utc)),
    ErlangUtc = erlzeit:to_erlang_calendar_datetime_utc(EzTime),
    erlang:display(ErlangUtc),
    ErlangLocal = erlzeit:to_erlang_calendar_datetime_local(EzTime),
    erlang:display(ErlangLocal),
    ErlangUtc2 = hd(calendar:local_time_to_universal_time_dst(ErlangLocal)),
    erlang:display(ErlangUtc2),
    ?assertEqual(ErlangUtc, ErlangUtc2).

add_seconds_fractional_test() ->
    erlang:display("add_seconds_fractional_test"),
    EzTime = erlzeit:from_erlang_calendar_datetime_utc({{2019, 1, 1}, {0, 0, 0}}),
    erlang:display(EzTime),
    EzTime2 = erlzeit:add_seconds(EzTime, 0.5),
    ?assertEqual({{2019, 1, 1}, {0, 0, 0.5}}, erlzeit:to_erlang_calendar_datetime_utc(EzTime2)),
    erlang:display(EzTime2),
    EzTime3 = erlzeit:add_seconds(EzTime2, -0.5),
    erlang:display(EzTime3),
    ?assertEqual(EzTime, EzTime3).

add_seconds_fractional_2_test() ->
    erlang:display("add_seconds_fractional_2_test"),
    EzTime = erlzeit:from_erlang_calendar_datetime_utc({{2019, 1, 1}, {0, 0, 0}}),
    erlang:display(EzTime),
    EzTime2 = erlzeit:add_seconds(EzTime, -0.5),
    ?assertEqual(
        {{2018, 12, 31}, {23, 59, 59.5}}, erlzeit:to_erlang_calendar_datetime_utc(EzTime2)
    ),
    erlang:display(EzTime2),
    EzTime3 = erlzeit:add_seconds(EzTime2, 0.5),
    erlang:display(EzTime3),
    ?assertEqual(EzTime, EzTime3).

to_from_utc_test() ->
    NowUTC = erlzeit:now(utc),
    NowLocal = erlzeit:to_local(NowUTC),
    NowUTC2 = erlzeit:to_utc(NowLocal),
    ?assertEqual(NowUTC, NowUTC2).

seconds_between_frac_test() ->
    erlang:display("seconds_between_frac_test"),
    EzTime1 = erlzeit:from_erlang_calendar_datetime_utc({{2019, 1, 1}, {0, 1, 2.25}}),
    EzTime2 = erlzeit:from_erlang_calendar_datetime_utc({{2019, 1, 1}, {0, 2, 1.55}}),
    ?assertEqual(59.3, erlzeit:seconds_between_frac(EzTime1, EzTime2)),
    ?assertEqual(59.8, erlzeit:seconds_between_frac(EzTime1, erlzeit:add_seconds(EzTime2, 0.5))),
    ?assertEqual(59, erlzeit:seconds_between_round(EzTime1, EzTime2)),
    ?assertEqual(60, erlzeit:seconds_between_round(EzTime1, erlzeit:add_seconds(EzTime2, 0.5))),
    ?assertEqual(59, erlzeit:seconds_between_trunc(EzTime1, EzTime2)),
    ?assertEqual(59, erlzeit:seconds_between_trunc(EzTime1, erlzeit:add_seconds(EzTime2, 0.5))),
    ?assertEqual(-59.3, erlzeit:seconds_between_frac(EzTime2, EzTime1)),
    ?assertEqual(-59, erlzeit:seconds_between_round(EzTime2, EzTime1)),
    ?assertEqual(-59, erlzeit:seconds_between_trunc(EzTime2, EzTime1)).
