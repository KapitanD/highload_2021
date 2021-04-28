#!/usr/bin/env bash

# Запускаем 3 инстанса в фоновом режиме
tarantool server_instance.lua 1 &
tarantool server_instance.lua 2 &
tarantool server_instance.lua 3 &
# Ждем их запуска
sleep 1

# Запускаем один инстанс в интерактивном режиме и вызываем функцию Update_cfg
echo "Update_cfg({10025, 10026, 10027, box.NULL})" | tarantool -i server_instance.lua 4 > /dev/null

sleep 1
# Проверяем, что последняя строчка лога - остановка нашего сервера
if [[ `tail -n 1 ./data/10024/instance_4.log` =~ stopped ]]; then
    echo "Correct updated cfg"
else
    echo "Incorrect updated cfg"
fi
# Проверяем, что первый инстанс сменил свой порт на 10025
if [[ -n `curl localhost:10025 2> /dev/null` ]]; then echo 'Port of 1st instance changed'; fi

kill -9 `cat ./data/10021/instance_1.pid 2> /dev/null` > /dev/null
kill -9 `cat ./data/10022/instance_2.pid 2> /dev/null` > /dev/null
kill -9 `cat ./data/10023/instance_3.pid 2> /dev/null` > /dev/null