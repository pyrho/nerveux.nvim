local M = {}
local l = require "nerveux.log"
local actions = require "telescope.actions"
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local previewers = require "telescope.previewers"
local conf = require "telescope.config".values
local Job = require "plenary.job"
local entry_display = require "telescope.pickers.entry_display"
local u = require "nerveux.utils"
local nerveux_config = require "nerveux.config"

--- Spawns a call to `neuron` to query all zettels
-- @param opts
-- @field opts.uplinks_of (string) Will query for the uplinks of that zettel ID
-- @field opts.backlinks_of (string) Will query for the backlinks of that zettel ID
-- @field opts.use_cache (boolean) use the --cached switch
-- @field opts.neuron_dir (string) the root directory of the zettelkasten
-- @field opts.neuron_cmd (string) the command to run to execute neuron
-- @param callback The function to call when the results are ready
--        In the form callback(error, table_of_results)
function M.get_all_zettels(opts, callback)
  opts = opts or {}
  opts.uplinks_of = opts.uplinks_of or false
  opts.backlinks_of = opts.backlinks_of or false

  local job_args = {"-d", opts.neuron_dir, "query"}

  if (opts.use_cache or true) then table.insert(job_args, "--cached") end

  if opts.backlinks_of then
    table.insert(job_args, "--backlinks-of")
    table.insert(job_args, opts.backlinks_of)
  else
    if opts.uplinks_of then
      table.insert(job_args, "--uplinks-of")
      table.insert(job_args, opts.uplinks_of)
    else
      table.insert(job_args, "--zettels")
    end
  end

  -- this is really bad, this function is called by telescope each time the user input changes...
  local job = Job:new{command = opts.neuron_cmd, args = job_args}
  job:start()

  job:after_failure(function() print("Error!") end)

  job:after_success(function(j)
    local lines = j:result()

    -- We need to defer this call because `vim.fn.json_decode`
    -- cannot be called in a vimL callback
    vim.schedule_wrap(function()
      local parsed_results = vim.fn.json_decode(lines)

      if opts.backlinks_of or opts.uplinks_of then
        if parsed_results[1] == nil or parsed_results[1].result == nil then
          l.error("Results malformed: " .. vim.inspect(parsed_results))
          return
        end
        return callback(nil, vim.tbl_map(function(e) return e[2] end,
                                         parsed_results[1].result))
      else
        return callback(nil, parsed_results)
      end

    end)()
  end)

end

--- Search
function M.search_zettel(opts)

  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

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

  M.get_all_zettels({
    uplinks_of = opts.uplinks_of,
    backlinks_of = opts.backlinks_of,
    neuron_dir = nerveux_config.neuron_dir,
    neuron_cmd = nerveux_config.neuron_cmd,
    use_cache = nerveux_config.use_cache
  }, function(_, results)
    pickers.new({
      attach_mappings = function(_, map)
        map("i", "<tab>", function(prompt_bufnr)
          local entry = actions.get_selected_entry()
          actions.close(prompt_bufnr)
          vim.api.nvim_put({"[[" .. entry.ID .. "]]"}, "c", true, true)
        end)

        return true
      end,

      prompt_title = opts.prompt or "Find/Insert Zettel",
      -- since `neuron query` returns all the zettels at once we don't need
      -- to continously update the query in regards to what the user has typed
      -- Use the `finders.new_table` to just have a static list of results
      finder = finders.new_table {results = results, entry_maker = maker},
      previewer = previewers.vim_buffer_cat.new {},
      sorter = conf.generic_sorter(opts)
    }):find()

  end)

end

return M
