local yaml = require("yaml")
local client = require("http.client")
local fio = require("fio")

local fh, err = fio.open("config.yaml")
if err ~= nil then
    print("Can't open file: " .. err)
    return 1
end

local config = yaml.decode(fh:read())
