#!/bin/bash
# test_server.sh - Тестирование IoT сервера из shell

echo "=== Запуск тестирования IoT сервера ==="

# 1. Запуск ребара и компиляция
echo "1. Компиляция проекта..."
rebar3 compile || { echo "Ошибка компиляции!"; exit 1; }

# 2. Запуск оболочки Erlang с приложением
echo "2. Запуск Erlang shell..."
erl -pa _build/default/lib/*/ebin \
    -pa _build/default/lib/*/include \
    -config sys.config.json \
    -eval "application:start(iotserv)" \
    -noshell \
    -sname test_node \
    -setcookie test_cookie << 'EOF'

%% ===== Тестирование клиентских API =====

io:format("~n=== Тестирование клиентских API ===~n~n").

%% 1. Подключение устройства
io:format("1. Тест подключения устройства:~n").
DeviceId = "device_123",
{ok, Pid} = iotserv_client:connect(DeviceId),
io:format("   Устройство ~s подключено, PID: ~p~n", [DeviceId, Pid]).

%% 2. Отправка данных с устройства
io:format("~n2. Тест отправки данных:~n").
Data1 = #{temperature => 23.5, humidity => 65.2, timestamp => erlang:system_time(millisecond)},
Result1 = iotserv_client:send_data(DeviceId, Data1),
io:format("   Данные отправлены: ~p~n", [Result1]).

%% 3. Получение последних данных
io:format("~n3. Тест получения данных:~n").
LastData = iotserv_client:get_last_data(DeviceId),
io:format("   Последние данные устройства ~s: ~p~n", [DeviceId, LastData]).

%% 4. Получение статистики
io:format("~n4. Тест получения статистики:~n").
Stats = iotserv_client:get_statistics(DeviceId),
io:format("   Статистика устройства ~s: ~p~n", [DeviceId, Stats]).

%% 5. Установка конфигурации
io:format("~n5. Тест установки конфигурации:~n").
Config = #{report_interval => 5000, max_retries => 3, alert_threshold => 30.0},
Result2 = iotserv_client:set_config(DeviceId, Config),
io:format("   Конфигурация установлена: ~p~n", [Result2]).

%% 6. Получение конфигурации
io:format("~n6. Тест получения конфигурации:~n").
CurrentConfig = iotserv_client:get_config(DeviceId),
io:format("   Текущая конфигурация: ~p~n", [CurrentConfig]).

%% 7. Подписка на события
io:format("~n7. Тест подписки на события:~n").
Self = self(),
Result3 = iotserv_client:subscribe(DeviceId, alerts, Self),
io:format("   Подписка оформлена: ~p~n", [Result3]).

%% 8. Отправка тестового события
io:format("~n8. Тест отправки события:~n").
Event = #{type => high_temperature, value => 35.0, device => DeviceId},
Result4 = iotserv_client:send_event(Event),
io:format("   Событие отправлено: ~p~n", [Result4]).

%% 9. Проверка получения события
io:format("~n9. Ожидание события (5 секунд)...~n").
receive
    {alert, AlertData} ->
        io:format("   Получено событие: ~p~n", [AlertData])
after 5000 ->
    io:format("   Событие не получено (таймаут)~n")
end.

%% 10. Отключение устройства
io:format("~n10. Тест отключения устройства:~n").
Result5 = iotserv_client:disconnect(DeviceId),
io:format("   Устройство отключено: ~p~n", [Result5]).

%% 11. Получение списка устройств
io:format("~n11. Тест получения списка устройств:~n").
DevicesList = iotserv_client:list_devices(),
io:format("   Активные устройства: ~p~n", [DevicesList]).

%% 12. Получение состояния системы
io:format("~n12. Тест получения состояния системы:~n").
SystemStatus = iotserv_client:system_status(),
io:format("   Состояние системы: ~p~n", [SystemStatus]).

%% Завершение
io:format("~n=== Тестирование завершено ===~n").

%% Остановка приложения
application:stop(iotserv),
init:stop().

EOF

echo "=== Тестирование завершено ==="