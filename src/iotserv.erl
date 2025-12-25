-module(iotserv).
-behaviour(gen_server).

-record(device, {
    id :: binary(),
    name :: binary(),
    address :: binary(),
    temperature :: float(),
    metrics :: list()
}).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).


-export([add/5, delete/1, change/2, lookup/1, get_all/0, stop/0]).

-record(state, {table_name :: atom()}).


start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

add(Id, Name, Address, Temperature, Metrics) ->
    gen_server:call(?MODULE, {add, Id, Name, Address, Temperature, Metrics}).

delete(Id) ->
    gen_server:call(?MODULE, {delete, Id}).

change(Id, Updates) ->
    gen_server:call(?MODULE, {change, Id, Updates}).

lookup(Id) ->
    gen_server:call(?MODULE, {lookup, Id}).

get_all() ->
    gen_server:call(?MODULE, get_all).

stop() ->
    gen_server:call(?MODULE, stop).

init([]) ->
    process_flag(trap_exit, true),
    {ok, TableName} = iotserv_db:init(),
    {ok, #state{table_name = TableName}}.

handle_call({add, Id, Name, Address, Temperature, Metrics}, _From, State) ->
    Device = #device{
        id = Id,
        name = Name,
        address = Address,
        temperature = Temperature,
        metrics = Metrics
    },
    Result = iotserv_db:add_device(Device),
    {reply, Result, State};

handle_call({delete, Id}, _From, State) ->
    Result = iotserv_db:delete_device(Id),
    {reply, Result, State};

handle_call({change, Id, Updates}, _From, State) ->
    Result = iotserv_db:update_device(Id, Updates),
    {reply, Result, State};

handle_call({lookup, Id}, _From, State) ->
    Result = iotserv_db:lookup(Id),
    {reply, Result, State};

handle_call(get_all, _From, State) ->
    Result = iotserv_db:get_all(),
    {reply, Result, State};

handle_call(stop, _From, State) ->
    iotserv_db:stop(),
    {stop, normal, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    iotserv_db:stop(),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.