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
    Job:new({command = "kill", args = {"-9", daemon_job.pid}}):sync()
  end
end

function nerveux.add_all_virtual_titles(buf, is_overlay)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
  for ln, line in ipairs(lines) do
    nerveux.add_virtual_title_current_line(buf, ln, line, is_overlay)
  end
end

local function query_id(id, callback)
  local job_args = {"query", "--id", id}

  if config.use_cache then table.insert(job_args, "--cached") end

  Job:new{
    command = config.neuron_cmd,
    args = job_args,
    cwd = config.neuron_dir,
    on_exit = vim.schedule_wrap(function(job --[[, return_val--]] )
      local data = table.concat(job:result())
      if #data == 0 or data == nil then return end

      callback(vim.fn.json_decode(data))
    end)
  }:start()
end

function nerveux.add_virtual_title_current_line(buf, ln, line, is_overlay)
  if type(line) ~= "string" then return end
  local all_links = u.get_all_link_indices(line)

  local all_titles = {}
  local nb_resolved = 0

  -- Final callback, once all the IDs have be queried
  local function on_done(all)
    -- This is called on `BufWrite` so this gets executed on `:wq` but has
    -- an async call to `neuron`.
    -- When the async calls back, the buffer is no longer visible so an
    -- error is thrown because it seems you can't add extmarks to a hidden buffer (which
    -- makes sense).
    -- This check helps with this issue.
    -- We need to add `+ 0` here to cast buf as number, otherwise the call to
    -- bufwinnr always returns -1 because the string is not valid
    if vim.fn.bufwinnr(buf + 0) == -1 then return end

    if is_overlay then
      for _, v in ipairs(all) do
        local start_col_patched, _, extmark_opts = unpack(v)
        vim.api.nvim_buf_set_extmark(buf, ns, ln - 1, start_col_patched - 1,
                                     extmark_opts)
      end
    else
      local all_only_titles = {}
      for _, v in ipairs(all) do
        local _, title = unpack(v)
        table.insert(all_only_titles, title)
      end
      -- We want to display all the titles as virutal text
      -- at the end of the line
      local extmarkopts = {
        end_col = 0,
        virt_text = {
          {table.concat(all_only_titles, ","), config.virtual_title_hl}
        }
      }

      vim.api.nvim_buf_set_extmark(buf, ns, ln - 1, 1, extmarkopts)
    end
  end

  for k, v in ipairs(all_links) do
    table.insert(all_titles, "")
    local start_col, end_col, id, is_folgezettel = unpack(v)
    local hl = (function()
      if is_folgezettel then
        return config.virtual_title_hl_folge
      else
        return config.virtual_title_hl
      end
    end)()

    query_id(id, function(json)
      nb_resolved = nb_resolved + 1
      if type(json) == "userdata" then return end
      if json == nil then return end
      if json.error then return end

      local title = (function()
        local is_at_eol = #line == end_col

        if is_overlay then
          do
            return u.rpad(json.Title, end_col + 1 - start_col, is_at_eol)
          end
        else
          return json.Title
        end
      end)()

      local extmark_opts = nil

      if is_overlay then
        extmark_opts = {
          virt_text_pos = "overlay",
          virt_text_hide = true,
          end_col = end_col,
          virt_text = {{title, hl}}
        }
      end

      -- This is needed because there seems to be a bug in
      -- `virt_text_pos="overlay" when the virtual text starts at column 0`
      local start_col_patched = (function()
        if start_col == 1 then
          return 2
        else
          return start_col
        end
      end)()

      all_titles[k] = {start_col_patched, title, extmark_opts}

      -- All the links have been queried, call the final callback to actually
      -- display the titles
      if nb_resolved == #all_links then on_done(all_titles) end
    end)
  end

end

local function setup_autocmds()
  local pathpattern = string.format("%s/*.md", config.neuron_dir)
  vim.cmd [[augroup Nerveux]]
  vim.cmd [[au!]]

  vim.cmd(string.format(
              [[ au BufLeave %s lua require'nerveux'.update_last_zettel_id(vim.fn.expand("%%:t:r")) ]],
              pathpattern))

  if config.virtual_titles == true then
    -- I don't yet understand why but having this autocmd on BufEnter causes an error where
    -- after choosing a file via telescope (or FZF buffer switch) we are somehow trying
    -- to set the virtual text on the wrong buffer and if the line is out of range it will cause an error.
    -- vim.cmd(
    --     string.format([[au BufEnter %s lua require'nerveux'.update_virtual_titles(vim.fn.expand("<abuf>"), true)]], pathpattern)
    -- )
    vim.cmd(string.format(
                [[au BufRead %s lua require'nerveux'.update_virtual_titles(true)]],
                pathpattern))
    vim.cmd(string.format(
                [[au InsertLeave %s lua require'nerveux'.update_virtual_titles(true)]],
                pathpattern))
    vim.cmd(string.format(
                [[ au BufWrite %s lua require'nerveux'.update_virtual_titles(true) ]],
                pathpattern))
    vim.cmd(string.format(
                [[ au InsertEnter %s lua require'nerveux'.update_virtual_titles(false) ]],
                pathpattern, ns))
  end

  vim.cmd [[augroup END]]
end

function nerveux.grep_zettels()
  require"telescope.builtin".live_grep({cwd = config.neuron_dir})
end

--- Create a new zettel with neuron and open it in vim
function nerveux.new_zettel()
  Job:new{
    command = config.neuron_cmd,
    args = {"new"},
    cwd = config.neuron_dir,
    on_exit = vim.schedule_wrap(function(job)
      local data = table.concat(job:result())
      vim.cmd("edit " .. data)

      -- add a new line
      vim.cmd [[norm Go]]

      -- and another with the start of a header
      vim.cmd [[norm o# ]]
    end)
  }:start()
end

--- Starts the neuron daemon if not already launched (by us or prior)
-- Uses plenary.job to create the job and stores the handle in the `daemon_job` global
-- variable.
local function start_daemon()
  u.is_process_running("neuron", function(e, is_running)
    if e then l.error(e) end

    if not is_running then
      daemon_job = Job:new({
        command = config.neuron_cmd,
        args = {"gen", "-w"},
        cwd = config.neuron_dir,
        on_start = function() l.debug("Daemon started") end
      })

      l.debug("Daemon is not running, starting...")
      daemon_job:start()

      if config.start_daemon and config.kill_daemon_at_exit then
        vim.schedule_wrap(function()
          vim.cmd [[autocmd VimLeavePre * lua require'nerveux'.kill_daemon()]]
        end)()
      end
    end
  end)
end

function nerveux.open_zettel_under_cursor()
  local word = vim.fn.expand("<cWORD>")

  local id = u.match_link(word)

  if id == nil then
    vim.cmd("echo 'There is no link under the cursor'")
    return
  end

  query_id(id, function(json)
    if type(json) ~= "userdata" then
      vim.cmd(string.format("edit %s/%s.md", config.neuron_dir, json.ID))
    end
  end)
end

function nerveux.update_virtual_titles(is_overlay)
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  nerveux.add_all_virtual_titles(buf, is_overlay)
end

nerveux._LAST_EDITED_ZETTEL = nil
function nerveux.update_last_zettel_id(id)
  l.debug("Updating last zettel id: " .. id)
  nerveux._LAST_EDITED_ZETTEL = id
end

function nerveux.insert_last_zettel_id(is_folgezettel)
  if nerveux._LAST_EDITED_ZETTEL ~= nil then
    vim.api.nvim_put({
      "[[" .. nerveux._LAST_EDITED_ZETTEL .. "]]" ..
          (is_folgezettel and "#" or "")
    }, "", true, true)
  end
end

function nerveux.setup_default_mappings()
  if config.mappings.search_zettels ~= "" then
    vim.api.nvim_buf_set_keymap(0, "n", config.mappings.search_zettels,
                                [[<Cmd>lua require"nerveux.search".search_zettel {}<CR>]],
                                {noremap = true, silent = true})
  end

  if config.mappings.backlinks_search ~= "" then
    vim.api.nvim_buf_set_keymap(0, "n", config.mappings.backlinks_search,
                                [[<Cmd>lua require"nerveux.search".search_zettel {backlinks_of = require"nerveux.utils".get_zettel_id_from_fname(), prompt = "Search Backlinks"}<CR>]],
                                {noremap = true, silent = true})
  end

  if config.mappings.uplinks_search ~= "" then
    vim.api.nvim_buf_set_keymap(0, "n", config.mappings.uplinks_search,
                                [[<Cmd>lua require"nerveux.search".search_zettel {uplinks_of = require"nerveux.utils".get_zettel_id_from_fname(), prompt = "Search Uplinks"}<CR>]],
                                {noremap = true, silent = true})
  end

  if config.mappings.new ~= "" then
    vim.api.nvim_buf_set_keymap(0, "n", config.mappings.new,
                                [[<Cmd>lua require"nerveux".new_zettel()<CR>]],
                                {noremap = true, silent = true})
  end

  if config.mappings.search_content ~= "" then
    vim.api.nvim_buf_set_keymap(0, "n", config.mappings.search_content,
                                [[<Cmd>lua require"nerveux".grep_zettels()<CR>]],
                                {noremap = true, silent = true})
  end

  if config.mappings.insert_link ~= "" then
    vim.api.nvim_buf_set_keymap(0, "n", config.mappings.insert_link,
                                [[<Cmd>lua require"nerveux".insert_last_zettel_id(false)<CR>]],
                                {noremap = true, silent = true})
  end

  if config.mappings.insert_link_folge ~= "" then
    vim.api.nvim_buf_set_keymap(0, "n", config.mappings.insert_link_folge,
                                [[<Cmd>lua require"nerveux".insert_last_zettel_id(true)<CR>]],
                                {noremap = true, silent = true})
  end

  if config.mappings.help ~= "" then
    vim.api.nvim_buf_set_keymap(0, "n", config.mappings.help,
                                [[<Cmd>lua require"nerveux.help".show_help()<CR>]],
                                {noremap = true, silent = true})
  end

  if config.mappings.follow ~= "" then
    vim.api.nvim_buf_set_keymap(0, "n", config.mappings.follow,
                                [[<Cmd>lua require"nerveux".open_zettel_under_cursor()<CR>]],
                                {noremap = true, silent = true})
  end
end

nerveux.setup = function(opts)
  ns = vim.api.nvim_create_namespace("nerveux.nvim")
  if config._loaded then return end
  config._loaded = true

  opts = opts or {}
  config.virtual_titles = opts.virtual_titles or false
  config.neuron_cmd = opts.neuron_cmd or "neuron"
  config.start_daemon = opts.start_daemon or false

  -- The path must not end with a `/` !
  -- Otherwise it will fuck up the autocmd
  config.neuron_dir = opts.neuron_dir or vim.loop.cwd()

  config.use_cache = opts.use_cache or opts.start_daemon or false
  config.kill_daemon_at_exit = opts.kill_daemon_at_exit or false

  config.virtual_title_hl = opts.virtual_title_hl or "Special"
  config.virtual_title_hl_folge = opts.virtual_title_hl_folge or "Repeat"

  opts.mappings = opts.mappings or {}

  config.mappings = {
    search_zettels = "gzz",
    backlinks_search = "gzb",
    uplinks_search = "gzu",
    new = "gzn",
    search_content = "gzs",
    insert_link = "gzl",
    insert_link_folge = "gzL",
    follow = "<CR>",
    help = "gz?"
  }

  for k, v in pairs(opts.mappings) do config.mappings[k] = v end

  if opts.start_daemon then start_daemon() end

  if opts.create_default_mappings then
    vim.cmd("augroup NerveuxMappings")
    vim.cmd("autocmd!")

    -- Paths with spaces need to be escaped otherwise the autocommand will
    -- not register appropriately
    local escaped_path = config.neuron_dir:gsub(" ", "\\ ")

    vim.cmd(string.format(
                [[autocmd BufRead %s/*.md lua require'nerveux'.setup_default_mappings()]],
                escaped_path))
    vim.cmd("augroup END")
  end

  setup_autocmds()
end

return nerveux
