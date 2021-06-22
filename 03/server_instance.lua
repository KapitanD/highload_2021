#!usr/bin/env tarantool

local netbox = require('net.box')
local yaml = require('yaml')
local fio = require('fio')
local swim = require('swim')
local log = require('log')
local socket = require('socket')
local http_server = require('server')

if #arg ~= 1 then
    print("Incorrect number of parameters. Usage: server_instance.lua <idx>")
    return 1
end

local idx = tonumber(arg[1])

local fh, err = fio.open('config.yaml')
if err ~= nil then
    print("Can't open config file: " .. err)
    return 1
end

local raw_data, err = fh:read()
if err ~= nil then
    print("Can't read config file: " .. err)
end

local config = yaml.decode(raw_data)

local server = http_server:new(config, idx)

local user = 'admin' .. tostring(idx)
local password = 'admin' .. tostring(idx)

local work_dir = fio.pathjoin('data', server:get_uri())
fio.mktree(work_dir)

local function can_use_port(port)
    local sock = socket('AF_INET', 'SOCK_STREAM', 'tcp')
    local ok = sock:bind('0.0.0.0', port)
    local err = sock:error()
    sock:close()
    if not ok then
        return false, err
    end
    return true
end

local function connect(instance, auth_payload)
    local conn_str = auth_payload.user..':'..auth_payload.password..'@'..instance.host..':'..instance.port
    log.info('Try to connect to %s...', conn_str)
    local conn = netbox.connect(conn_str, {wait_connected = false, reconnect_after = 5})
    return conn
end

function Query(new_port)
    if new_port == box.NULL then
        return true
    end
    local ok, err = can_use_port(new_port)
    if ok then
        return true
    else
        return false, err
    end
end

function Commit(new_port)
    if new_port ~= box.NULL then
        server:set_port(new_port)
        server:restart()
    else
        server:stop()
    end
end

box.cfg({
    listen = server:get_admin_port(),
    work_dir = work_dir,
    log = 'instance_'..tostring(idx)..'.log',
    pid_file = 'instance_'..tostring(idx)..'.pid',
})
box.schema.user.create(user, {password = password, if_not_exists= true})
box.schema.user.grant(user, 'execute', 'universe', nil, {if_not_exists=true})

_G.swim = swim.new()
_G.swim:cfg({
    uuid = server:get_uuid(),
    uri = server:get_uri(),
    heartbeat_rate = 1,
    ack_timeout = 15,
    gc_mode = 'off',
})

local instances = config.instances

for i = 1, #instances do
    _G.swim:probe_member(instances[i].port)
end

_G.swim:set_payload({
    user = user,
    password = password,
})

local instances_with_conn = {}

for i = 1, #instances do
    local instance = instances[i]
    instances_with_conn[instance.uuid] = {host = instance.host, port = instance.admin_port, conn = nil}
end

_G.swim:on_member_event(
function(m, e)
    if e:is_new_payload() then
        if m:status() == "dead" then
            return
        end
        local uuid = tostring(m:uuid())
        log.info('Instance with uuid:%s update its payload, try to connect...', uuid)
        instances_with_conn[uuid].conn = connect(instances_with_conn[uuid], m:payload())
    end
end
)

function Update_cfg(new_cfg)
    for i = 1, #instances do
        if i ~= idx then
            local instance = instances[i]
            local instance_view = _G.swim:member_by_uuid(instance.uuid)

            if instance_view == nil or instance_view:status() == "dead" then
                log.error("Instance %s is dead, rollback...", instance.uuid, err)
                return
            end

            local ok, err = instances_with_conn[instance.uuid].conn:call('Query', {new_cfg[i]})
            if not ok then
                log.error("Instance %s cant apply new cfg, reason: %s, rollback...", instance.uuid, err)
                return
            end
        else
            local ok, err = can_use_port(new_cfg[i])
            if not ok then
                log.error("This instance cant apply new cfg, reason: %s, rollback... ", err)
                return
            end
        end
    end
    log.info("All instances could apply new config, commit...")
    for i = 1, #instances do 
        if i ~= idx then
            local instance = instances[i]
            log.info("Restart %s instance http-server", instance.uuid)
            instances_with_conn[instance.uuid].conn:call('Commit', {new_cfg[i]})
        else
            log.info("Restart this instance http-server")
            Commit(new_cfg[i])
        end
    end
end

server:start()

return {
    update_cfg = Update_cfg
}
