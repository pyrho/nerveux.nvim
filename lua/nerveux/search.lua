local M = {}
local F = require "plenary.functional"
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local Job = require("plenary.job")
local a = require("plenary.async_lib")
local entry_display = require("telescope.pickers.entry_display")
local async = a.async
local u = require "nerveux.utils"
local nerveux_config = require "nerveux.config"

function M.search_zettel(opts)
  local function trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end

  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  opts.uplinks = opts.uplinks or false
  opts.backlinks = opts.backlinks or false

  local displayer = entry_display.create {
    separator = "▏",
    -- items is a table with 2 entries, so each entry must have 2 "fields"
    items = {{width = 16}, {remaining = true}}
  }

  local maker = function(deets)
    deets.valid = true
    deets.display = function(entry)
      return displayer {
        table.concat(u.map(entry["Meta"]["tags"],
                           function(tag) return "#" .. tag end), ","),
        entry["Title"]
      }
    end
    deets.value = vim.fn.resolve(string.format("%s/%s",
                                               nerveux_config.neuron_dir,
                                               deets["Path"]))
    deets.ordinal = deets["Title"]
    return deets
  end

  local query_neuron = async(function(needle)
    -- Wait for 2 characters to search
    -- if string.len(trim(needle)) < 2 then
    --     return {}
    -- end

    local job_args = {"-d", nerveux_config.neuron_dir, "query"}

    if nerveux_config.use_cache then table.insert(job_args, "--cached") end

    if opts.backlinks then
      table.insert(job_args, "--backlinks-of")
      table.insert(job_args, opts.backlinks)
    else
      if opts.uplinks then
        table.insert(job_args, "--uplinks-of")
        table.insert(job_args, opts.uplinks)
      else
        table.insert(job_args, "--zettels")
      end
    end

    print(vim.inspect(job_args))
    local job = Job:new{command = nerveux_config.neuron_cmd, args = job_args}

    local lines = job:sync()

    local parsed_results = vim.fn.json_decode(lines)

    if opts.backlinks or opts.uplinks then
      return vim.tbl_map(function(e) return e[2] end, parsed_results.result)
    else
      return parsed_results
    end
  end)

  pickers.new(opts, {
    attach_mappings = function(_, map)
      map("i", "<tab>", function(prompt_bufnr)
        local entry = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.api.nvim_put({"[[" .. entry.ID .. "]]"}, "c", true, true)
      end)

      return true
    end,

    prompt_title = opts.prompt or "Find/Insert Zettel",
    finder = finders.new_dynamic {entry_maker = maker, fn = query_neuron},
    previewer = previewers.vim_buffer_cat.new {},
    sorter = conf.generic_sorter(opts)
  }):find()
end

return M
