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
function utils.lpad(s, l, is_eol)
    local short_or_eq = #s <= l
    local ss = (is_eol or short_or_eq) and s or (string.sub(s, 0, l) .. "…")
    local res = string.rep(" ", l - #ss) .. s

    return res
end

--- Stolen from https://github.com/blitmap/lua-snippets/blob/master/string-pad.lua
function utils.pad(s, l, is_eol)
    local res1 = utils.rpad(s, (l / 2) + #s, is_eol) -- pad to half-length + the length of s
    local res2 = utils.lpad(res1, l, is_eol) -- right-pad our left-padded string to the full length

    return res2
end

--- Stolen from https://github.com/blitmap/lua-snippets/blob/master/string-pad.lua
function utils.rpad(s, l, is_eol)
    local short_or_eq = #s <= l
    local ss = (is_eol or short_or_eq) and s or (string.sub(s, 1, l - 1) .. "…")
    local res = ss .. string.rep(" ", l - #ss)

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

function utils.get_zettel_id_from_fname()
    return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t:r")
end

return utils
