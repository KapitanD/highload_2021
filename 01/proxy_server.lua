local yaml = require('yaml')
local http_client = require('http.client')
local fio = require('fio')
local uri = require('uri')
local fio = require('fio')

local work_dir = fio.pathjoin('data', 'proxy_server')
fio.mktree(work_dir)

box.cfg({
    log='proxy_server.log',
    pid_file='proxy_server.pid',
    work_dir=work_dir
})



local fh, err = fio.open('config.yaml')
if err ~= nil then
    print("Can't open file: " .. err)
    return 1
end

local client = http_client.new()

local raw_data, err = fh:read()
if err ~= nil then
    print("Can't read file")
    return 1
end

local config= yaml.decode(raw_data)

local function proxy_handler(req)
    local method = req:method()

    local scheme = ''
    if config.proxy.bypass.port == 80 then
        scheme = 'http'
    elseif config.proxy.bypass.port == 443 then
        scheme = 'https'
    else
        scheme = 'http'
    end

    local proxy_url_full = uri.format({
        host=config.proxy.bypass.host,
        service=tostring(config.proxy.bypass.port),
        path=req:path(),
        scheme = 'http',
    })
    print(proxy_url_full)

    local body = req:read()
    if body == '' then
        body = nil
    end

    local headers = req:headers()
    headers.host = config.proxy.bypass.host

    local resp = client:request(method, proxy_url_full, body, {headers = headers, timeout = 1, follow_location = true})

    print(resp.status)
    print(resp.body)
    if resp.headers ~= nil then
        for key, val in pairs(resp.headers) do
            print(key, val)
        end
    end
    return {
        status = resp.status,
        headers = resp.headers,
        body = resp.body
    }
end

local router = require('http.router').new()
router:route({path = '/.*', method = 'ANY'}, proxy_handler)
router:route({path = '/', method = 'ANY'}, proxy_handler)

local server = require('http.server').new('localhost', config.proxy.port)
server:set_router(router)

server:start()
