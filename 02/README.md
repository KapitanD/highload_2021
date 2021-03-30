# Домашнее задание 2
## Балансировщик нагрузки
Есть 2 скрипта. Модуль load_balancer.lua, предоставляющий в качестве интерфейса 2 функции - init() - запуск балансировщика, и reload() - перезагрузка конфига, конфиг в config.yaml. Скрипт server_instance.lua запускает тестовый сервер, который умеет считать кол-во входящих запросов за последнюю секунду.
Как тестировал - запускал 4 тестовых сервера
```
tarantool -i server_instance.lua localhost 8081
tarantool -i server_instance.lua localhost 8082
tarantool -i server_instance.lua localhost 8083
tarantool -i server_instance.lua localhost 8084
```
, затем запускал балансировщик
```
tarantool
tarantool> load_balancer = require('load_balancer')
           load_balancer.init()
```
Можно затем уронить пару серверов, потом поднять их, все должно работать.
Пример конфига:
```
---
load_balancer:
  host: localhost
  port: 8080
  hosts:
    - host: localhost
      port: 8081
      user: admin
      password: admin
    - host: localhost
      port: 8082
      user: admin
      password: admin
    - host: localhost
      port: 8083
      user: admin
      password: admin
    - host: localhost
      port: 8084
      user: admin
      password: admin
```