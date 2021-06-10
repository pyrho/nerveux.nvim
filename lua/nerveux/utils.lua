local utils = {}
local Job = require "plenary.job"

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
