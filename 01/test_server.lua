-- Simle server
local fio = require('fio')

local work_dir = fio.pathjoin('data', 'test_server')
fio.mktree(work_dir)

box.cfg({
    log='test_server.log',
    pid_file='test_server.pid',
    work_dir=work_dir,
})

local function hello()
    return {
        status = 200,
        body = 'hello, world'
    }
end

local router = require('http.router').new()
router:route({ method = 'GET', path = '/hello' }, hello)

local server = require('http.server').new('localhost', 9000)
server:set_router(router)

server:start()
