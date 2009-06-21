-module(timeout_server).

-behaviour(gen_server).

-export([start_link/0, call_later/4, call_now/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
		 terminate/2, code_change/3]).

%%%%%%%%%%%%%%%%%%%%%%
%% public functions %%
%%%%%%%%%%%%%%%%%%%%%%

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

call_later(M, F, A, Timeout) ->
	gen_server:cast(?MODULE, {call_later, {M, F, A}, Timeout}).

call_now(MFA) -> gen_server:cast(?MODULE, {call_now, MFA}).

%%%%%%%%%%%%%%%%
%% gen_server %%
%%%%%%%%%%%%%%%%

init(_Args) -> {ok, dict:new()}.

handle_call(Request, _, State) -> {reply, Request, State}.

handle_cast({call_later, MFA, Timeout}, Timers) ->
	{ok, TRef} = timer:apply_after(Timeout, ?MODULE, call_now, [MFA]),
	% if there is an existing TRef, cancel it, then store new TRef
	U = fun(Old) -> timer:cancel(Old), TRef end,
	{noreply, dict:update(MFA, U, TRef, Timers)};
handle_cast({call_now, {M, F, A}}, Timers) ->
	% spawn MFA, erase timer (assumes timer has been executed)
	proc_lib:spawn(M, F, A),
	{noreply, dict:erase({M, F, A}, Timers)};
handle_cast(_, State) ->
	{noreply, State}.

handle_info(_, State) -> {noreply, State}.

terminate(_, Timers) ->
	F = fun({_, TRef}) -> timer:cancel(TRef) end,
	lists:foreach(F, dict:to_list(Timers)).

code_change(_, State, _) -> {ok, State}.
