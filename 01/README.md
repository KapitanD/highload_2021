# Задание №1 - Прокси сервер на Tarantool
Файл proxy_server.lua - прокси сервер, передает хэдеры, inline queries, и т.д.
Known bugs:
 - При попытки прокси гугла (google.com) курл выдает странную ошибку ```curl: (56) Illegal or missing hexadecimal sequence in chunked-encoding```