local nerveux = {}

local Job = require "plenary.job"
local fzf = require("fzf")

local utils = require "nerveux.utils"

local config = {}

nerveux.kill_daemon = function()
    -- This does not work, I think because it's not doing its thing
    -- fast enough
    -- daemon_job:shutdown()

    Job:new(
        {
            command = "pkill",
            args = {"neuron"}
        }
    ):sync()
end

local function start_daemon()
    utils.is_process_running(
        "neuron",
        function(e, is_running)
            if not is_running then
                print("not running, starting daemon")
                local daemon_job =
                    Job:new(
                    {
                        command = config.neuron_cmd,
                        args = {
                            "gen",
                            "-w"
                        },
                        cwd = config.neuron_dir,
                    }
                )
                daemon_job:start()

                if config.kill_daemon_at_exit then
                    vim.schedule_wrap(
                        function()
                            vim.cmd [[autocmd VimLeavePre * lua require'nerveux'.kill_daemon()]]
                        end
                    )()
                end
            end
        end
    )
end

nerveux.setup = function(opts)
    if config.loaded then
        return
    end
    config.loaded = true

    -- nvim-fzf will inherit this setting.
    -- Override it to control the look n feel of fzf
    vim.env.FZF_DEFAULT_OPTS = nil
    opts = opts or {}
    config.neuron_cmd = opts.neuron_cmd or "neuron"
    config.neuron_dir = opts.neuron_dir or error("`neuron_dir` option must be provided.`")
    config.bat_cmd = opts.bat_cmd or "bat --color=always --style=snip"
    config.use_cache = opts.use_cache or opts.start_daemon or false
    config.kill_daemon_at_exit = opts.dangerously_kill_daemon_at_exit or false

    if opts.start_daemon then
        print("start daemon requested...")
        start_daemon()
    end

    if opts.create_default_mappings then
        vim.api.nvim_set_keymap(
            "n",
            "gzz",
            [[<Cmd>lua require('nerveux').open_zettel()<CR>]],
            {noremap = true, silent = true}
        )
    end
end

nerveux.open_zettel = function()
    local function gotDataCb(data)
        coroutine.wrap(
            function()
                local x = vim.fn.json_decode(data)

                local function pick_object(list_of_objects)
                    local fzf_input = {}
                    for idx, v in ipairs(list_of_objects) do
                        table.insert(fzf_input, tostring(idx) .. "\t" .. tostring(v.Path) .. "\t" .. tostring(v.Title))
                    end
                    local choices =
                        fzf.fzf(
                        fzf_input,
                        "--delimiter='\t' --preview='" ..
                            config.bat_cmd .. " " .. config.neuron_dir .. "/{2}' --with-nth=3"
                    )
                    if not choices then
                        return nil
                    end
                    local idx = tonumber(string.match(choices[1], "^(%d+)\t"))
                    return list_of_objects[idx]
                end

                local choice = pick_object(x)
                vim.cmd("e" .. config.neuron_dir .. choice.Path)
            end
        )()
    end

    local jobArgs = {
        "-d",
        config.neuron_dir,
        "query",
        "--zettels"
    }

    if config.use_cache then
        table.insert(jobArgs, "--cached")
    end

    local job1 =
        Job:new(
        {
            command = config.neuron_cmd,
            args = jobArgs
        }
    )
    job1:start()
    job1:after_success(
        function(j)
            vim.schedule_wrap(
                function()
                    gotDataCb(j:result())
                    return
                end
            )()
        end
    )
end

return nerveux
