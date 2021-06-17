local nerveux = {}

local Job = require "plenary.job"

local u = require "nerveux.utils"
local l = require "nerveux.log"

local config = require "nerveux.config"

local ns = nil
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

function nerveux.add_all_virtual_titles(buf)
    for ln, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, true)) do
        nerveux.add_virtual_title_current_line(buf, ln, line)
    end
end

local function query_id(id, callback)
    local job_args = {
        "query",
        "--id",
        id
    }

    if config.use_cache then
        table.insert(job_args, "--cached")
    end

    local query_job =
        Job:new {
        command = config.neuron_cmd,
        args = job_args,
        cwd = config.neuron_dir,
        on_exit = vim.schedule_wrap(
            function(job --[[, return_val--]])
                local data = table.concat(job:result())
                if #data == 0 or data == nil then
                    return
                end

                callback(vim.fn.json_decode(data))
            end
        )
    }:start()
end

function nerveux.add_virtual_title_current_line(buf, ln, line)
    if type(line) ~= "string" then
        return
    end
    local id = u.match_link(line)
    if id == nil then
        return
    end
    local start_col, end_col = u.find_link(line)

    query_id(
        id,
        function(json)
            if type(json) == "userdata" then
                return
            end
            if json == nil then
                return
            end
            if json.error then
                return
            end
            local title = json.Title
            vim.api.nvim_buf_set_extmark(
                buf,
                ns,
                ln - 1,
                start_col - 1,
                {
                    end_col = end_col,
                    virt_text = {{title, config.virtual_title_hl}}
                }
            )
        end
    )
end

local function setup_autocmds()
    local pathpattern = string.format("%s/*.md", config.neuron_dir)
    vim.cmd [[augroup Nerveux]]
    vim.cmd [[au!]]

    if config.virtual_titles == true then
        vim.cmd(string.format("au BufRead %s lua require'nerveux'.add_all_virtual_titles()", pathpattern))
        vim.cmd(string.format([[ au BufWrite %s lua require'nerveux'.update_virtual_titles() ]], pathpattern))
    end

    vim.cmd [[augroup END]]
end

function nerveux.new_zettel()
    Job:new {
        command = config.neuron_cmd,
        args = {"new"},
        cwd = config.neuron_dir,
        --[[
        -- neuron is pretty chatty on stderr...
        on_stderr = vim.schedule_wrap(
            function(_, data)
                if data ~= nil then
                    vim.cmd(string.format("echoerr 'An error occured from running %s: %s'", "neuron new", data))
                end
            end
        ),
        --]]
        on_exit = vim.schedule_wrap(
            function(job --[[, return_val--]])
                local data = table.concat(job:result())
                vim.cmd("edit " .. data)
            end
        )
    }:start()
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

                if config.start_daemon and config.kill_daemon_at_exit then
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

function nerveux.open_zettel_under_cursor()
    local word = vim.fn.expand("<cWORD>")

    print(word)
    local id = u.match_link(word)

    if id == nil then
        vim.cmd("echo 'There is no link under the cursor'")
        return
    end

    query_id(
        id,
        function(json)
            if type(json) ~= "userdata" then
                vim.cmd(string.format("edit %s/%s.md", config.neuron_dir, json.ID))
            end
        end
    )
end

function nerveux.update_virtual_titles(buf)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    nerveux.add_all_virtual_titles()
end

nerveux.setup = function(opts)
    ns = vim.api.nvim_create_namespace("nerveux.nvim")
    if config._loaded then
        return
    end
    config._loaded = true

    opts = opts or {}
    config.virtual_titles = opts.virtual_titles or false
    config.neuron_cmd = opts.neuron_cmd or "neuron"

    -- The path must not end with a `/` !
    -- Otherwise it will fuck up the autocmd
    config.neuron_dir = opts.neuron_dir or vim.loop.cwd()

    config.use_cache = opts.use_cache or opts.start_daemon or false
    config.kill_daemon_at_exit = opts.kill_daemon_at_exit or false

    config.virtual_title_hl = opts.virtual_title_hl or "Special"

    if opts.start_daemon then
        start_daemon()
    end

    if opts.create_default_mappings then
        vim.api.nvim_set_keymap(
            "n",
            "gzz",
            [[<Cmd>lua require('telescope').extensions.nerveux.search {}<CR>]],
            {noremap = true, silent = true}
        )

        vim.api.nvim_set_keymap(
            "n",
            "gzn",
            [[<Cmd>lua require('nerveux').new_zettel()<CR>]],
            {noremap = true, silent = true}
        )

        vim.api.nvim_set_keymap(
            "n",
            "<CR>",
            [[<Cmd>lua require('nerveux').open_zettel_under_cursor()<CR>]],
            {noremap = true, silent = true}
        )
    end
    setup_autocmds()
end

return nerveux
