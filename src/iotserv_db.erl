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
    
    TableName = iot_devices,
    
    DetsPathStr = binary_to_list(maps:get(<<"dets_path">>, IotConfig)),
  
    ensure_directory(DetsPathStr),
    

    case dets:open_file(TableName, [{file, DetsPathStr}, {type, set}, {keypos, 2}]) of
        {ok, _} ->
            %% 5. Создаем ETS копию в памяти
            ets:new(TableName, [set, named_table, protected, {keypos, #device.id}]),
            load_from_dets(TableName),
            {ok, TableName};
        {error, Reason} ->
            {error, Reason}
    end.

ensure_directory(Path) ->
    Dirname = filename:dirname(Path),
    case filelib:is_dir(Dirname) of
        true -> ok;
        false -> file:make_dir(Dirname)
    end.

load_from_dets(TableName) ->
    
    dets:traverse(TableName, fun({_Key, Device}) ->
        ets:insert(TableName, Device),
        continue
    end).

add_device(Device) ->
    TableName = iot_devices,
    

    ets:insert(TableName, Device),

    dets:insert(TableName, Device),
    
    ok.

delete_device(Id) ->
    TableName = iot_devices,
    

    ets:delete(TableName, Id),
    

    dets:delete(TableName, Id),
    
    ok.

update_device(Id, Updates) ->
    TableName = iot_devices,
    
    case ets:lookup(TableName, Id) of
        [Device] ->
            UpdatedDevice = apply_updates(Device, Updates),
            
            ets:insert(TableName, UpdatedDevice),
            
            dets:insert(TableName, UpdatedDevice),
            
            {ok, UpdatedDevice};
        [] ->
            {error, device_not_found}
    end.

lookup(Id) ->
    TableName = iot_devices,
    case ets:lookup(TableName, Id) of
        [Device] ->
            {ok, Device};
        [] ->
            {error, device_not_found}
    end.

get_all() ->
    TableName = iot_devices,
    ets:tab2list(TableName).

stop() ->
    TableName = iot_devices,
    dets:close(TableName),

    ets:delete(TableName),
    ok.

apply_updates(Device, Updates) ->
    lists:foldl(fun({Field, Value}, Acc) ->
        set_field(Acc, Field, Value)
    end, Device, maps:to_list(Updates)).

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