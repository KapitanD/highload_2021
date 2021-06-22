local http_server = require('http.server')
local httpd_router = require('http.router')

Server = {}

function Server:my_uuid_handler()
    local uuid = self.config.uuid
    return function()
        return {
            status = 200,
            body = self.config.uuid
        }
    end
end

function Server:new(config, idx)
    local new_server = {server = nil, config = config.instances[idx]}
    
    local server = http_server.new(new_server.config.host, new_server.config.port)
    new_server.server = server

    self.__index = self
    setmetatable(new_server, self)

    new_server:setup_router()
    return new_server
end

function Server:setup_router()
    local router = httpd_router.new()
    router:route({ method = 'GET', path = '/' }, self:my_uuid_handler())
    self.server:set_router(router) 
end

function Server:start()
    self.server:start()
end

function Server:stop()
    print(self)
    self.server:stop()
end

function Server:get_uuid()
    return self.config.uuid
end

function Server:get_uri()
    return self.config.port
end

function Server:set_port(new_port)
    self.config.port = new_port
end

function Server:restart()
    self.server:stop()
    self.server = http_server.new(self.config.host, self.config.port)
    self:setup_router()
    self.server:start()
end

function Server:get_admin_port()
    return self.config.admin_port
end

return Server