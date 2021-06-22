#!/usr/bin/env bash

tarantool test_server.lua &> /dev/null &

tarantool proxy_server.lua &> /dev/null &

sleep 1

curl localhost:10000/ -v &> test_1.txt
curl localhost:10000/hello -v &> test_2.txt

if [[ -n `cat test_1.txt | grep 'HTTP/1.1 404 Not found'` ]]; then
    echo "Test 1 - req to incorrect path: passed"
else
    echo "Test 1 - req to incorrect path: failed"
fi

if [[ -n `cat test_2.txt | grep 'HTTP/1.1 200 Ok'` ]] && [[ -n `cat test_2.txt | grep 'hello, world'` ]]; then
    echo "Test 2 - req to correct path: passed"
else
    echo "Test 2 - req to correct path: failed"
fi


kill `cat data/proxy_server/proxy_server.pid`
kill `cat data/test_server/test_server.pid`
rm test_1.txt test_2.txt