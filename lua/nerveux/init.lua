local nerveux = {}

local Job = require "plenary.job"
local ListView = require "guihua.listview"
local TextView = require "guihua.textview"
local ghutil = require "guihua.util"

local u = require "nerveux.utils"
local l = require "nerveux.log"

local config = {}

local daemon_job = nil

--- Kill the neuron daemon.
-- Expored because we need to call it via an autocmd
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

--- Starts the neuron daemon if not already launched (by us or prior)
-- Uses plenary.job to create the job and stores the handle in the `daemon_job` global
-- variable.
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

--- Plugin setup function, called with a table to overwrite the default
-- @tparam string opts.neuron_cmd The path to the neuron executable
-- @tparam string opts.neuron_dir The path to the root directory of your zettelkasten
-- @tparam string opts.bat_cmd The path to the bat (fancy cat) executable
-- @tparam boolean opts.use_cache Make use of neuron's cache, implies opts.start_daemon
-- @tparam boolean opts.start_daemon Let nerveux handle the neuron daemon lifecycle (so that the cache is up to date) (Default: false)
-- @tparam boolean opts.kill_daemon_at_exit If nerveux has started the daemon, it will kill it at exit (Default: false)
-- @tparam boolean opts.create_default_mappings Set the default mappings (Default: false)
nerveux.setup = function(opts)
    if config.loaded then
        return
    end

    config.loaded = true

    opts = opts or {}
    config.neuron_cmd = opts.neuron_cmd or "neuron"
    config.neuron_dir = u.append_slash(opts.neuron_dir or error("`neuron_dir` option must be provided.`"))
    config.use_cache = opts.use_cache or opts.start_daemon or false
    config.kill_daemon_at_exit = opts.kill_daemon_at_exit or false
    config.start_daemon = opts.start_daemon or false
    config.create_default_mappings = opts.create_default_mappings or false

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
    local list_height = 5

    local function getLinesAndData(list_of_objects)
        local data = {}
        for _, v in ipairs(list_of_objects) do
            table.insert(
                data,
                {
                    uri = vim.uri_from_fname(config.neuron_dir .. v.Path),
                    filename = config.neuron_dir .. v.Path,
                    text = v.Title
                }
            )
        end
        return data
    end

    local function gotDataCb(json_data)
        local list_of_objects = vim.fn.json_decode(json_data)
        local data = getLinesAndData(list_of_objects)

        local function preview_uri(uri, line, offset_y)
            -- log(uri)
            -- Take into account the window decoration
            offset_y = offset_y or 10
            local range = {
                ["end"] = {
                    character = 1,
                    line = line + 20
                },
                start = {
                    character = 1,
                    line = 0
                }
            }
            local text_view_opts = {
                loc = "top_center",
                rect = {height = 20, width = 90, pos_x = 0, pos_y = offset_y + list_height},
                uri = uri,
                range = range,
                edit = false,
                syntax = "markdown"
            }

            local win = TextView:new(text_view_opts)
            return win
        end

        local on_move = function(pos)
            if pos == 0 then
                pos = 1
            end
            if pos > #data then
                l.error("[ERR] idx", pos, "length ", #data)
            end
            -- local loc = data[pos]
            l.debug('ONMOVE>>')
            l.debug(data)
            -- @BUG 
            -- the issue currently is that **every** items
            -- have a score, some negative so 0.xxx
            l.debug('ONMOVE<<')
            local loc = ghutil.fzy_idx(data, pos)

            return preview_uri(loc.uri, 1)
        end

        local open_file_at = function(filename, line)
            vim.api.nvim_command(string.format("e! +%s %s", line, filename))
        end

        local on_confirm = function(pos)
            if pos == 0 then
                pos = 1
            end
            local loc = ghutil.fzy_idx(data, pos)
            -- local loc = data[pos]
            -- l.debug(loc)
            if l.filename ~= nil then
                open_file_at(loc.filename, 0)
            end
        end

        local win =
            ListView:new(
            {
                loc = "top_center",
                prompt = true,
                rect = {height = list_height, width = 90},
                data = data,
                on_confirm = on_confirm,
                on_move = on_move
            }
        )

        -- not sure what this is for..
        win:set_pos(1)
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

nerveux.open_zettel_old = function()
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

-- Works !
--[[
local ns = vim.api.nvim_create_namespace("ta mere")
 vim.api.nvim_buf_set_virtual_text(0, ns,172, {{"TEE", "Keyword"}}, {})
 vim.defer_fn(function()
     vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
 end, 2000)
--]]
-- nerveux.open_zettel()
-- test_filepreview()

return nerveux
