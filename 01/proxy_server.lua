local yaml = require('yaml')
local http_client = require('http.client')
local fio = require('fio')

local fh, err = fio.open('config.yaml')
if err ~= nil then
    print("Can't open file: " .. err)
    return 1
end

local client = http_client.new()
local config = yaml.decode(fh:read())
local proxy_url = config.proxy.bypass.host .. ':' .. config.proxy.bypass.port


local function proxy_handler(req)
    local method = req:method()
    local proxy_url_full = proxy_url..req:path()
    if req:query() ~= '' then
        proxy_url_full = proxy_url_full..'?'..req:query()
    end
    local body = req:read()
    local headers = req:headers()
    local resp = client:request(method, proxy_url_full, body, {headers = headers})
    return resp
end

local router = require('http.router').new()
router:route({path = '/.*', method = 'ANY'}, proxy_handler)

local server = require('http.server').new('localhost', config.proxy.port)
server:set_router(router)

server:start()