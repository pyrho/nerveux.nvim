local Log = require "plenary.log"
local p_debug = vim.fn.getenv("DEBUG_NERVEUX")
if p_debug == vim.NIL then
    p_debug = false
end

local M = Log.new(
    {
        -- Name of the plugin. Prepended to log messages
        plugin = "nerveux",
        -- Should print the output to neovim while running
        -- values: 'sync','async',false
        use_console = 'async',
        -- Should highlighting be used in console (using echohl)
        highlights = true,
        -- Should write to a file
        use_file = true,
        -- Any messages above this level will be logged.
        level = p_debug and "debug" or "info",
        -- Level configuration
        modes = {
            {name = "trace", hl = "Comment"},
            {name = "debug", hl = "Comment"},
            {name = "info", hl = "None"},
            {name = "warn", hl = "WarningMsg"},
            {name = "error", hl = "ErrorMsg"},
            {name = "fatal", hl = "ErrorMsg"}
        },
        -- Can limit the number of decimals displayed for floats
        float_precision = 0.01
    },
    true
)

return M
