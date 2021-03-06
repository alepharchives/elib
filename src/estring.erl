%% ``The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved via the world wide web at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% The Initial Developer of the Original Code is Jacob Perkins.
%% All Rights Reserved.''
%%
%% @author Jacob Perkins

%% @doc Extra string functions that aren't available in stdlib string module.

-module(estring).

-export([startswith/2, endswith/2, contains/2, format/2, lower/1, shared_prefix/2]).
-export([join/2, read_file/1, random/1]).
-export([split/2, splitc/2, tokenize/2]).
-export([replace/3, replace_all/3]).
-export([strip/1, strip_all/2, striptokens/1, striptokens/2]).
-export([to_title/1, title_word/1, is_upper/1]).
-export([lcs_len/2, similar/2, partial_match/2]).
-export([urldecode/1, querydecode/1]).
-export([is_utf8/1, encode_utf8/1, utf8_to_unicode/1]).
-export([trim/1]).

startswith(S, Prefix) -> lists:prefix(Prefix, S).

endswith(S, Suffix) -> lists:suffix(Suffix, S).

contains(S, Sub) -> string:str(S, Sub) /= 0.

format(Format, Data) -> lists:flatten(io_lib:format(Format, Data)).

lower(B) when is_binary(B) -> lower(binary_to_list(B));
lower(S) when is_list(S) -> string:to_lower(S).

join([], _) -> [];
join(List, Sep) -> string:join(List, Sep).

shared_prefix(S1, S2) -> lists:reverse(shared_prefix(S1, S2, [])).

% accumulate characters from front of strings until characters are not equal
shared_prefix([C | S1], [C | S2], Pre) -> shared_prefix(S1, S2, [C | Pre]);
shared_prefix(_, _, Pre) -> Pre.

%% @doc Splits String at first instance of Sep. This is an alternative to
%% string:tokens that is much more efficient if you know that you only need to
%% split once. Fails if Sep is not found in String.
%%
%% @spec split(string(), string()) -> [string() + string()]
%% @see string:tokens/2
split(S, Sep) ->
	case string:str(S, Sep) of
		0 ->
			[S];
		I ->
			{Head, Tail} = lists:split(I - 1, S),
			[Head, lists:nthtail(length(Sep), Tail)]
	end.

%% @doc Faster, character based version of split/2.
%%
%% @spec splitc(string(), char()) -> {string(), string()}
splitc(S, C) -> splitc(S, C, []).

splitc([], _, Head) -> {lists:reverse(Head), []};
splitc([C | Tail], C, Head) -> {lists:reverse(Head), Tail};
splitc([Char | Tail], C, Head) -> splitc(Tail, C, [Char | Head]).

%% @doc Return a list containing tokens from each string.
%%
%% @spec tokenize([string()], string()) -> [string()]
%% @see string:tokens/2
tokenize(Strings, Sep) ->
	lists:append(lists:map(fun(S) -> string:tokens(S, Sep) end, Strings)).

%% @doc Returns the contents of file as a list.
%%
%% @spec read_file(string()) -> list()
%% @see file:read_file/1
read_file(Filename) ->
	{ok, Bin} = file:read_file(Filename),
	binary_to_list(Bin).

%% @doc Replace first instance of Key in String with Val.
%% Returns {error, notfound} if Ky is not in String.
%%
%% @spec replace(string(), string(), string()) -> Result
%%		 Result = {ok, string()} | {error, notfound}
replace(String, Key, Val) when is_list(String), is_list(Key), is_list(Val) ->
	case string:str(String, Key) of
		0 ->
			{error, notfound};
		Start ->
			{First, Rest} = lists:split(lists:max([1, Start - 1]), String),
			Last = string:substr(Rest, length(Key) + 1),
			{ok, First ++ Val ++ Last}
	end.

%% @doc Replaces all instances of Key in String with Val. If there are no
%% instances of Key in String, then will return {ok, String}.
%%
%% @spec replace_all(string(), string(), string()) -> {ok, string()}
%% @see replace/3
replace_all(String, Key, Val) ->
	case replace(String, Key, Val) of
		{error, notfound} -> {ok, String};
		{ok, NewString} -> replace_all(NewString, Key, Val)
	end.

%% @doc Strips newline and whitespace characters from String. string:strip only
%% strips whitespace by default.
%%
%% @spec strip(string()) -> string()
%% @see string:strip/3
%% @see string:strip/1
strip(String) -> string:strip(string:strip(String, both, $\n)).

%% @doc Strip all characters from both ends of string.
%%
%% @spec strip_all(string(), [char()]) -> string()
%% @see string:strip/3
strip_all(String, Chars) ->
	F = fun(C, S) -> string:strip(S, both, C) end,
	lists:foldl(F, String, Chars).

%% @doc Tokenize the string, then strip each token.
%%
%% @spec striptokens(string()) -> [string()]
%% @equiv striptokens(String, ",")
striptokens(String) -> striptokens(String, ",").

%% @doc Tokenize the string with separators, then strip each token.
%%
%% @spec striptokens(string(), string()) -> [string()]
%% @see string:tokens/2
striptokens(String, Sep) -> [strip(S) || S <- string:tokens(String, Sep)].

%% @doc Title cases String, calling title_word/1 on each word.
%%
%% @spec to_title(string()) -> string()
%% @see title_word/1
to_title(String) ->
	join([title_word(W) || W <- string:tokens(String, " ")], " ").

%% @doc Title case word by converting first character to upper case and rest
%% of characters to lower case.
%%
%% @spec title_word(string()) -> string()
%% @see string:to_upper/1
%% @see string:to_lower/1
title_word([]) -> [];
title_word([C | Rest]) -> [string:to_upper(C) | string:to_lower(Rest)].

%% @doc Tests if String is upper case.
%%
%% @spec is_upper(string()) -> bool()
%% @see string:to_upper/1
is_upper(String) -> String == string:to_upper(String).

%% @doc Return length of the longest common subsequence (lcs) between two lists.
%% Use this function to find out how similar two strings are. Think of the
%% lcs_len as the 'edit distance' between two strings, meaning the number of
%% edits required to go from one string to the other.
%%
%% @spec lcs_len(list(), list()) -> integer()
%% @todo Optimize by first creating a suffix tree, then search that suffix tree
%% for the lcs. Current method is too slow.
lcs_len([], _) -> 0;
lcs_len(_, []) -> 0;
lcs_len(A, B) ->
	BSeq = lists:reverse(lists:seq(1, length(B))),
	
	F = fun(I, L1) ->
			G = fun(J, L2) -> lcs_len(A, I, B, J, L2) end,
			lists:foldl(G, L1, BSeq)
		end,
	
	% use reverse sequences so can iteratively build from end of strings
	ASeq = lists:reverse(lists:seq(1, length(A))),
	List = lists:foldl(F, [], ASeq),
	proplists:get_value({1, 1}, List, 0).

lcs_len(A, I, B, J, List) ->
% returns proplist with len value for {I, J}
	AI = lists:nth(I, A),
	BJ = lists:nth(J, B),
	
	if
		AI == BJ ->
			V = 1 + proplists:get_value({I + 1, J + 1}, List, 0),
			[{{I, J}, V} | List];
		true ->
			M1 = proplists:get_value({I + 1, J}, List, 0),
			M2 = proplists:get_value({I, J + 1}, List, 0),
			[{{I, J}, lists:max([M1, M2])} | List]
	end.

%% @doc Test if two strings are similar using the ratio of the lcs_len divided
%% by length of the shortest string. Strings are lowercased before comparing.
%%
%% @spec similar(string(), string()) -> bool()
%% @see lcs_len/2
similar([], _) ->
	false;
similar(_, []) ->
	false;
similar(A, B) ->
	Overlap = lcs_len(string:to_lower(A), string:to_lower(B)),
	Max = lists:min([length(A), length(B)]),
	(Overlap / Max) >= 0.7.

%% @doc Tests if two strings are similar using prefix and suffix matching.
%% The strings are similar if A is a prefix or suffix of B. This function is an
%% interim replacement for similar/2 until lcs_len/2 is optimized.
%%
%% @spec partial_match(string(), string()) -> bool()
partial_match(B, A) when length(B) > length(A) ->
	partial_match(A, B);
partial_match(A, B) ->
	{A1, B1} = {string:to_lower(A), string:to_lower(B)},
	lists:prefix(A1, B1) orelse lists:suffix(A1, B1).

%% @doc Returns a random alphanumeric string of length Size.
%%
%% @spec random(integer()) -> string()
%% @see emath:random/1
random(Size) ->
	Chars = lists:seq($0, $9) ++ lists:seq($A, $Z) ++ lists:seq($a, $z),
	N = length(Chars),
	F = fun(_, S) -> [lists:nth(emath:random(N), Chars) | S] end,
	lists:foldl(F, [], lists:seq(1, Size)).

%% @doc Decode the query part of a url.
%%
%% @spec urldecode(string()) -> [{string(), string()}]
%% @see querydecode/1
urldecode(URL) ->
	case string:tokens(URL, "?") of
		[URL] -> [];
		[_Front, Query] -> querydecode(Query)
	end.

%% @doc Decode a url query string.
%%
%% @spec querydecode(string()) -> [{string(), string()}]
%% @see split/2
querydecode(Query) ->
	F = fun(Var) ->
			[Key, Val] = split(Var, "="),
			{Key, Val}
		end,
	
	lists:map(F, string:tokens(Query, "&")).

%% @doc Test if string is utf-8 encoded.
%%
%% @spec is_utf8(string()) -> bool()
%% @see xmerl_ucs:is_incharset/2
is_utf8(String) ->
	try lists:all(fun(C) -> xmerl_ucs:is_incharset(C, 'utf-8') end, String)
	catch
		exit:{ucs, {bad_utf8_character_code}} -> false
	end.

%% @doc Encode a string as utf-8.
%%
%% @equiv xmerl_ucs:to_utf8(String)
encode_utf8(String) -> xmerl_ucs:to_utf8(String).

%% @doc Convert a utf-8 string to unicode.
%%
%% @equiv xmerl_ucs:to_unicode(String, 'utf-8')
utf8_to_unicode(String) -> xmerl_ucs:to_unicode(String, 'utf-8').

%% @doc Delete whitespace betwin word
%%
%% @equiv xmerl_ucs:trim(String, string()) -> list()
trim(String)  ->
    String2 = lists:dropwhile(fun is_whitespace/1, String),
    lists:reverse(lists:dropwhile(fun is_whitespace/1, lists:reverse(String2))).

is_whitespace($\s) ->
    true;
is_whitespace($\t) ->
    true;
is_whitespace($\n) ->
    true;
is_whitespace($\r) ->
    true;
is_whitespace(_Else) ->
    false.
