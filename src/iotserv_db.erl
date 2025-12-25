-module(iotserv_db).

-export([init/0, 
         add_device/1, 
         delete_device/1, 
         update_device/2,
         lookup/1,
         get_all/0,
         stop/0]).


-record(device, {
    id :: binary(),
    name :: binary(),
    address :: binary(),
    temperature :: float(),
    metrics :: list()
}).

init() ->
    {ok, ConfigBin} = file:read_file("sys.config.json"),
    Config = jsx:decode(ConfigBin, [return_maps]),
    
    IotConfig = maps:get(<<"iotserv">>, Config),
    DetsPath = maps:get(<<"dets_path">>, IotConfig),
    TableName = list_to_atom(maps:get(<<"table_name">>, IotConfig)),
    
    {ok, DetsRef} = dets:open_file(TableName, [{file, DetsPath}, {type, set}]),
    
    EtsRef = ets:new(TableName, [set, named_table, protected, {keypos, #device.id}]),
    
    load_from_dets(DetsRef, EtsRef),
    
    dets:close(DetsRef),
    
    {ok, TableName}.

load_from_dets(DetsRef, EtsRef) ->
    case dets:first(DetsRef) of
        '$end_of_table' ->
            ok;
        Key ->
            load_device(DetsRef, EtsRef, Key),
            load_rest(DetsRef, EtsRef, Key)
    end.

load_device(DetsRef, EtsRef, Key) ->
    case dets:lookup(DetsRef, Key) of
        [Device] ->
            ets:insert(EtsRef, Device);
        [] ->
            ok
    end.

load_rest(DetsRef, EtsRef, PrevKey) ->
    case dets:next(DetsRef, PrevKey) of
        '$end_of_table' ->
            ok;
        NextKey ->
            load_device(DetsRef, EtsRef, NextKey),
            load_rest(DetsRef, EtsRef, NextKey)
    end.

add_device(Device) ->
    TableName = get_table_name(),
    DetsPath = get_dets_path(),
    
    ets:insert(TableName, Device),

    {ok, DetsRef} = dets:open_file(TableName, [{file, DetsPath}]),
    dets:insert(DetsRef, Device),
    dets:close(DetsRef),
    
    ok.

delete_device(Id) ->
    TableName = get_table_name(),
    DetsPath = get_dets_path(),
    
    ets:delete(TableName, Id),
    
    {ok, DetsRef} = dets:open_file(TableName, [{file, DetsPath}]),
    dets:delete(DetsRef, Id),
    dets:close(DetsRef),
    
    ok.

update_device(Id, Updates) ->
    TableName = get_table_name(),
    DetsPath = get_dets_path(),
    
    case ets:lookup(TableName, Id) of
        [Device] ->
            UpdatedDevice = apply_updates(Device, Updates),
            
            ets:insert(TableName, UpdatedDevice),
            
            {ok, DetsRef} = dets:open_file(TableName, [{file, DetsPath}]),
            dets:insert(DetsRef, UpdatedDevice),
            dets:close(DetsRef),
            
            {ok, UpdatedDevice};
        [] ->
            {error, device_not_found}
    end.

lookup(Id) ->
    TableName = get_table_name(),
    case ets:lookup(TableName, Id) of
        [Device] ->
            {ok, Device};
        [] ->
            {error, device_not_found}
    end.

get_all() ->
    TableName = get_table_name(),
    ets:tab2list(TableName).

stop() ->
    TableName = get_table_name(),
    ets:delete(TableName),
    ok.

get_table_name() ->
    iot_devices.

get_dets_path() ->
    "data/devices.dets".

apply_updates(Device, Updates) ->
    lists:foldl(fun({Field, Value}, Acc) ->
        set_field(Acc, Field, Value)
    end, Device, Updates).

set_field(Device, name, Value) ->
    Device#device{name = Value};
set_field(Device, address, Value) ->
    Device#device{address = Value};
set_field(Device, temperature, Value) ->
    Device#device{temperature = Value};
set_field(Device, metrics, Value) ->
    Device#device{metrics = Value};
set_field(Device, _, _) ->
    Device.