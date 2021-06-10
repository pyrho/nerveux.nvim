local nerveux = {}

local Job = require "plenary.job"
local fzf = require("fzf")

local u = require "nerveux.utils"
local l = require "nerveux.log"

local config = {}

local daemon_job = nil

nerveux.kill_daemon = function()
    if daemon_job then
        l.debug("Daemon job was started, killing pid:" .. daemon_job.pid)
        Job:new(
            {
                command = "kill",
                args = {"-9", daemon_job.pid}
            }
        ):sync()
    end
end

local function start_daemon()
    u.is_process_running(
        "neuron",
        function(e, is_running)
            if e then
                l.error(e)
            end

            if not is_running then
                daemon_job =
                    Job:new(
                    {
                        command = config.neuron_cmd,
                        args = {
                            "gen",
                            "-w"
                        },
                        cwd = config.neuron_dir,
                        on_start = function()
                            l.debug("Daemon started")
                        end
                    }
                )

                l.debug("Daemon is not running, starting...")
                daemon_job:start()

                if config.kill_daemon_at_exit then
                    vim.schedule_wrap(
                        function()
                            vim.cmd [[autocmd VimLeavePre * lua require'nerveux'.kill_daemon()]]
                        end
                    )()
                end
            else
                l.debug("Daemon is already running, not starting")
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
