#!/usr/bin/env tarantool

local netbox = require('net.box')
local http_server = require('http.server')
local http_router = require('http.router')
local fio = require('fio')
local yaml = require('yaml')
local log = require('log')

local config = {}
local connections = {}
local conn_hosts = {}
local active_connections = 0
local req_num = 1

local function on_connect(conn)
    log.info('Connected to %s succesful!', conn.host_s)
    connections[conn.host_s].status = true
    connections[conn.host_s].conn = conn
    
    active_connections = active_connections + 1
end

local function on_disconnect(conn)
    log.info('Connection to %s refused, try to connect again', conn.host_s)
    connections[conn.host_s].status = false
    active_connections = active_connections - 1
end

local function reload()
    connections = {}
    conn_hosts = {}
    active_connections = 0
    req_num = 1

    local fh, err = fio.open('config.yaml')
    if err ~= nil then
        print("Can't open file: " .. err)
        return 1
    end
    config = yaml.decode(fh:read())
    for _, host in ipairs(config.load_balancer.hosts) do
        local host_s = host.user..':'..host.password..'@'..host.host..':'..host.port
        local conn = netbox.connect(host_s, {wait_connected = false, reconnect_after = 5})
        log.info('Try to connect to %s...', host_s)
        conn.host_s = host_s
        connections[host_s] = {status = false, conn = nil}
        table.insert(conn_hosts, conn.host_s)
        conn:on_connect(on_connect)
        conn:on_disconnect(on_disconnect)
        assert(conn)
    end
end


local function handler()
    if active_connections == 0 then
        return {
            body = 'error: all servers is down',
            status = 500,
        }
    end

    if req_num == #conn_hosts then
        req_num = 1
    else
        req_num = req_num + 1
    end

    while not connections[conn_hosts[req_num]].status do
        if req_num == #conn_hosts then
            req_num = 1
        else
            req_num = req_num + 1
        end
    end

    local conn = connections[conn_hosts[req_num]].conn
    log.info('Try to send request to %d server', req_num)

    local result = conn:call('exec')

    return result
end

local function init()
    reload()

    local httpd = http_server.new(config.load_balancer.host, config.load_balancer.port, {log_requests = false})

    router = http_router.new()
    router:route({method = 'GET', path = '/'}, handler)

    httpd:set_router(router)
    httpd:start()
end

return {
    init = init,
    reload = reload,
}