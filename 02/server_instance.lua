#!/usr/bin/env tarantool

local http_server = require('http.server')
local http_router = require('http.router')
local clock = require('clock')
local fio = require('fio')

local host = arg[1]
local port = tonumber(arg[2])
if port == nil then
    error('Invalid port')
end

local work_dir = fio.pathjoin('data', port)
fio.mktree(work_dir)
box.cfg({
    listen = port,
    work_dir = work_dir,
})
box.schema.user.passwd('admin', 'admin')

local requests_times = {}

local function last_second_stats()
    local current_time = clock.monotonic64()
    table.insert(requests_times, current_time)
    while #requests_times ~= 0 and current_time - requests_times[1] > 1e9 do
        table.remove(requests_times, 1)
    end 
    body = host..':'..port..': '..tostring(#requests_times)
    return {
        body = body,
        status = 200,
    }
end

function exec()
    return last_second_stats()
end




