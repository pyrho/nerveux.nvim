# Nerveux

A neovim lua plugin to interact with [neuron](http://neuron.zettel.page).

![nerveux_normal](https://github.com/pyrho/static-imgs/raw/master/nerveux.jpeg)
See [this](https://asciinema.org/a/422065) asciinema recording for a little demo.

## Highlights

- Display zettle titles inline via virtual text overlays
    - in `insert` mode, the virtual text is place at the end of line
- Search Zettels and their content with [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- Cached queries via neuron daemon (for moar speed!)
    - daemon lifecycle is handled by the plugin

## Install
Using [vim-plug](https://github.com/junegunn/vim-plug)

```vimL
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'pyrho/nerveux.nvim'

" Optional but recommended for better markdown syntax
Plug 'plasticboy/vim-markdown'
```

or [packer](https://github.com/wbthomason/packer.nvim/)

```lua
use {
    'pyrho/nerveux.nvim',
    requires = {
        'nvim-lua/plenary.nvim',
        'nvim-lua/popup.nvim',
        'nvim-telescope/telescope.nvim',
    },
    config = function() require"nerveux".setup() end,
}
-- Optional but recommended for better markdown syntax
use 'plasticboy/vim-markdown'
```

## Setup

Simply add the following somewhere in your config to use the default settings.

```lua
require 'nerveux'.setup()
```

You can override the defaults like so:

```lua
require 'nerveux'.setup {
    --- path to neuron executable (default: neuron in PATH)
    neuron_cmd = "neuron",

    --- no trailing slash, (default: current directory)
    neuron_dir = "/my/zettel/root/dir",

    --- Use the cache, significantly faster (default: false)
    use_cache = true,

    --- start the neuron daemon to keep the cache up to date (default: false)
    start_daemon = true,

    --- show zettel titles inline as virtual text (default: false)
    virtual_titles = true,

    --- Automatically create mappings (default: false)
    create_default_mappings = true,

    --- The Highlight Group used for the inline zettel titles (default: Special)
    virtual_title_hl = "Special",
    virtual_title_hl_folge = "Repeat",

    --- `kill -9` the pid of the daemon at exit (VimPreLeave), only valid is
    -- start_daemon is true (default: false)
    kill_daemon_at_exit = true,

    --- You can overwrite this table partially
    -- and your settings will get merged with the defaults
    mappings = {

       -- Search all your zettels
       -- * then `<CR>` to edit
       -- * or `<Tab>` to insert the selected zettel ID under your cursor
       search_zettels = "gzz" ,

       -- Search the backlinks to the current zettel 
       backlinks_search = "gzb" ,

       -- Search the only the uplinks to the current zettel 
       uplinks_search = "gzu" ,

       -- Create a new zettel via neuron and :edit it
       new = "gzn" ,

       -- Search for content inside all the zettels
       search_content = "gzs" ,

       -- Insert the ID of the previously visited zettel
       insert_link = "gzl" ,

       -- Insert the ID of the previously visited zettel, but as a folgezettel
       insert_link_folge = "gzL" ,

       -- Open the zettel ID that's under the cursor
       follow = "<CR>" ,

       -- Show the help
       help = "gz?" ,
    }
}
```

## Similar plugins

- [oberblastmeister/neuron.nvim](https://github.com/oberblastmeister/neuron.nvim)
    - feature rich
    - from which nerveux.nvim borrows a lot of code
    - still active afaik
    - that's the one you should be using really :P
- [ihsanturk/neuron.vim](https://github.com/ihsanturk/neuron.vim)
    - OG vim neuron plugin, but long defunct
- [fiatjaf/neuron.vim](https://github.com/fiatjaf/neuron.vim)
    - A fork of the previous one, also defunct
- [chiefnoah/neuron-v2.vim](https://github.com/chiefnoah/neuron-v2.vim)
    - neuron v2 compatible, but also now defunct
