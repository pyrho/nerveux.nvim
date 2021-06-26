local M = {}

-- Stolen from [this](https://www.2n.pl/blog/how-to-write-neovim-plugins-in-lua)
-- great article
local api = vim.api

local function center(str)
  local width = api.nvim_win_get_width(0)
  local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
  return string.rep(' ', shift) .. str
end

function M.show_help()
  local buf = api.nvim_create_buf(false, true)
  local border_buf = api.nvim_create_buf(false, true)

  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'filetype', 'whid')

  local width = api.nvim_get_option("columns")
  local height = api.nvim_get_option("lines")

  local win_height = math.ceil(height * 0.5 - 4)
  local win_width = math.ceil(width * 0.8)
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    border = "shadow"
  }

  local win = api.nvim_open_win(buf, true, opts)

  -- we can add title already here, because first line will never change
  api.nvim_buf_set_lines(buf, 0, -1, false, { center('Nerveux Mappings Quickref (q quits)'), '', ''})
  api.nvim_buf_add_highlight(buf, -1, 'NerveuxHelpHeader', 0, 0, -1)

  local bindings = {
      { "  gzz        Search/Edit all Zettels (insert link with <Tab>)"},
      { "  gzs        Search for content in all zettels"},
      { "  <CR>       Follow link under cursor"},
      { "  gzb        Search all backlinks"},
      { "  gzu        Search uplinks only"},
      { "  gzn        Create new Zettel and edit"},
      { "  gzl        Insert previously visited zettel"},
      { "  gzL        Insert previously visited zettel as folgezettel"},
      { "  gz?        This help"},
  }


  local start_line = 2
  for key,value in ipairs(bindings) do 
      api.nvim_buf_set_lines(buf, start_line + key, start_line + key + 1, false, value)
      api.nvim_buf_add_highlight(buf, -1, 'NerveuxHelpText', start_line + key, 1, 6)
  end

  api.nvim_buf_set_keymap(buf, 'n', "q", ':q<CR>', { nowait = true, noremap = true, silent = true })
  return {buf, win}
end

return M
