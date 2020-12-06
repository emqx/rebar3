-module(stamp).

-export([maybe/5]).

-include("rebar.hrl").

maybe(State, AppInfo, What, Fun, DefaultResult) ->
    OutDir = rebar_app_info:out_dir(AppInfo),
    StampFile = get_stamp_file(OutDir),
    Stamp = get_stamp(rebar_state:current_profiles(State), OutDir),
    case is_stamped(StampFile, Stamp) of
        true ->
            ?INFO("Skipped ~s (stamp=~s)", [What, Stamp]),
            DefaultResult;
        false ->
            Result = Fun(),
            stamp(StampFile, Stamp),
            Result
    end.

get_stamp_file(Dir) ->
    FileName = getenv("REBAR3_PROJECT_BUILD_STAMP_FILE", ".stamp"),
    filename:join([Dir, FileName]).

get_stamp(Profiles, Dir) ->
    case getenv("REBAR3_PROJECT_BUILD_STAMP", false) of
        false -> false;
        "ignore" -> false;
        "auto" -> make_stamp(Profiles, Dir);
        Forced -> iolist_to_binary(Forced)
    end.

make_stamp(Profiles, Dir) ->
    SrcFiles = filelib:wildcard("**/*.{erl,hrl,c,cc,cpp,src}", Dir),
    Sums = lists:map(fun(F) ->
                             {ok, B} = file:read_file(filename:join([Dir, F])),
                             crypto:hash(sha, B)
                     end, SrcFiles),
    Stamp = hex(crypto:hash(sha, [Sums, io_lib:format("~p", [Profiles])])),
    ?DEBUG("Stamp ~s ~p ~s", [Dir, Profiles, Stamp]),
    Stamp.

hex(Bin) when is_binary(Bin) ->
    iolist_to_binary([io_lib:format("~2.16.0b",[X]) || <<X>> <= Bin]).

getenv(Name, Default) ->
    case os:getenv(Name) of
        false -> Default;
        "" -> Default;
        Val -> Val
    end.

stamp(_StampFile, false) -> ok;
stamp(StampFile, Stamp) ->
    file:write_file(StampFile, Stamp).

is_stamped(_StampFile, false) -> false;
is_stamped(StampFile, Stamp) ->
    filelib:is_regular(StampFile) andalso
        is_same_stamp(StampFile, Stamp).

is_same_stamp(StampFile, Stamp) ->
    {ok, ReadStamp} = file:read_file(StampFile),
    ReadStamp =:= Stamp.
