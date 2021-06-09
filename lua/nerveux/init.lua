local nerveux = {}
local Job = require'plenary.job'
local fzf = require('fzf')

--[[
-- Settings
]]
local neuron_dir = '/home/pyrho/Dropbox/zettelkasten/'
local bat_bin = "bat --color=always --style=snip"


local config = {}

-- For fzfnvim to work, the FZF options must be disabled
vim.env.FZF_DEFAULT_OPTS = nil

nerveux.setup = function(opts)
    opts = opts or {}
    config.neuron_dir = opts.neuron_dir or error('`neuron_dir` option must be provided.`')
end

nerveux.open_zettel = function()
    local function gotDataCb(data)
        coroutine.wrap(function()
            local x = vim.fn.json_decode(data)

            local function pick_object(list_of_objects)
                local fzf_input = {}
                for idx, v in ipairs(list_of_objects) do
                    table.insert(fzf_input, tostring(idx) .. "\t" .. tostring(v.Path) .. "\t" .. tostring(v.Title))
                end
                local choices = fzf.fzf(fzf_input, "--delimiter='\t' --preview='" .. bat_bin .. " " .. neuron_dir .. "/{2}' --with-nth=3")
                if not choices then return nil end
                local idx = tonumber(string.match(choices[1], "^(%d+)\t"))
                return list_of_objects[idx]
            end

            local choice = pick_object(x)
            vim.cmd('e' .. neuron_dir .. choice.Path )
        end)()
    end

    local job1 = Job:new({
        command = "neuron",
        args = {
            '-d',
            neuron_dir,
            'query',
            '--zettels',
            -- '--jsonl', <-- not a json, one json per line
            '--cached'
        },
    })
    job1:start()
    job1:after_success(function(j)
        vim.schedule_wrap(function()
            gotDataCb(j:result())
            return
        end)()
    end)
end

nerveux.open_zettel()

return nerveux
