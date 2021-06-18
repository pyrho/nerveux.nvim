local utils = {}
local Job = require "plenary.job"

local DOUBLE_LINK_RE = "%[%[([ A-Za-z0-9|]+)%]%]#?"

---@param s string
function utils.match_link(s)
    return s:match(DOUBLE_LINK_RE)
end

function utils.find_link(s)
    return s:find(DOUBLE_LINK_RE)
end

--- Stolen from https://github.com/blitmap/lua-snippets/blob/master/string-pad.lua

function utils.rpad(s, l, is_eol)

local short_or_eq = #s <= l
    local ss = (is_eol or short_or_eq) and s or (string.sub(s, 0, l ) .. "…")
    local res = ss .. string.rep(c or " ", l - #ss)

    return res
end

function utils.map(tbl, f)
    local t = {}
    for k, v in pairs(tbl) do
        t[k] = f(v)
    end
    return t
end

utils.is_process_running = function(process_name, cb)
    local j =
        Job:new(
        {
            command = "pgrep",
            args = {"-c", process_name}
        }
    )
    j:start()
    j:after_failure(
        function()
            return cb(nil, false)
        end
    )
    j:after_success(
        function(_, ret_code)
            return cb(nil, tonumber(ret_code) == 0)
        end
    )
end

return utils
