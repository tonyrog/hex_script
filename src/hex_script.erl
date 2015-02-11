%%%---- BEGIN COPYRIGHT -------------------------------------------------------
%%%
%%% Copyright (C) 2007 - 2014, Rogvall Invest AB, <tony@rogvall.se>
%%%
%%% This software is licensed as described in the file COPYRIGHT, which
%%% you should have received as part of this distribution. The terms
%%% are also available at http://www.rogvall.se/docs/copyright.txt.
%%%
%%% You may opt to use, copy, modify, merge, publish, distribute and/or sell
%%% copies of the Software, and permit persons to whom the Software is
%%% furnished to do so, under the terms of the COPYRIGHT file.
%%%
%%% This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
%%% KIND, either express or implied.
%%%
%%%---- END COPYRIGHT ---------------------------------------------------------
%%%-------------------------------------------------------------------
%%% @author Tony Rogvall <tony@rogvall.se>
%%% @doc
%%%    Hex script plugin 
%%% @end
%%% Created :  7 Feb 2014 by Tony Rogvall <tony@rogvall.se>
%%%-------------------------------------------------------------------
-module(hex_script).

-behaviour(hex_plugin).

-export([validate_event/2, 
	 event_spec/1,
	 init_event/2,
	 mod_event/2,
	 add_event/3, 
	 del_event/1, 
	 output/2]).

%%
%%  add_event(Flags::[{atom(),term()}, Signal::signal(), Cb::function()) ->    
%%     {ok, Ref:reference()} | {error, Reason}
%%
add_event(_Flags, _Signal, _Cb) ->
    {error, no_input}.

%%
%%  del_event(Ref::reference()) ->
%%     ok.
del_event(_Ref) ->
    {error, no_input}.

%%
%% output(Flags::[{atom(),term()}], Env::[{atom(),term()}]) ->
%%    ok.
%%
output(Flags, Env) ->
    run_output(Flags, Env).

%%
%% init_event(in | out, Flags::[{atom(),term()}])
%%
init_event(_, _) ->
    ok.

%%
%% mod_event(in | out, Flags::[{atom(),term()}])
%%
mod_event(_, _) ->
    ok.

%%
%% validate_event(in | out, Flags::[{atom(),term()}])
%%
validate_event(Dir, Flags) ->
    hex:validate_flags(Flags, event_spec(Dir)).

%%
%% return event specification in internal YANG format
%% {Type,Value,Stmts}
%%
event_spec(in) ->
    [];
event_spec(out) ->
    [{container,command,
      [{leaf,os,[{type,string,[]}]},
       {leaf,cmdline,[{type,string,[]},{mandatory,true,[]}]}
      ]}].

run_output([{command,Flags} | Commands], Env) ->
    case proplists:get_value(os, Flags, "") of
	"" ->
	    cmdline(proplists:get_value(cmdline,Flags), Env),
	    run_output(Commands, Env);
	Regex ->
	    case re:run(get_arch(), Regex, [{capture, none}]) of
		match ->
		    cmdline(proplists:get_value(cmdline,Flags), Env),
		    run_output(Commands, Env);
		nomatch ->
		    run_output(Commands, Env)
	    end
    end;
run_output([], _Env) ->
    ok.


%% generate architecture string for os match
get_arch() ->
    Words = wordsize(),
    erlang:system_info(otp_release) ++ "-"
        ++ erlang:system_info(system_architecture) ++ "-" ++ Words.

wordsize() ->
    try erlang:system_info({wordsize, external}) of
        Val -> integer_to_list(8 * Val)
    catch
        error:badarg ->
            integer_to_list(8 * erlang:system_info(wordsize))
    end.


cmdline(Cmdline0, Env) when is_list(Cmdline0) ->
    Cmdline = hex:text_expand(Cmdline0, Env),
    Port = erlang:open_port({spawn,Cmdline},[exit_status,eof]),
    wait_exit(Port).

%% wait for command to exit properly
wait_exit(Port) ->
    wait_exit(Port,-1).

wait_exit(Port,Status) ->
    receive
	{Port, {exit_status,Status1}} ->
	    wait_exit(Port,Status1);
	{Port, eof} ->
	    erlang:port_close(Port),
	    Status;
	{Port,{data,_Data}} ->
	    wait_exit(Port,Status)
    end.
