# Nerveux

A neovim lua plugin to interact with [neuron](http://neuron.zettel.page).

![nerveux_normal](https://github.com/pyrho/static-imgs/raw/master/photo.png)
![nerveux_normal](https://github.com/pyrho/static-imgs/raw/master/photo-1kj.png)

## Install
```vimL
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'pyrho/nerveux.nvim'
```

## Setup

Simply add the following somewhere in your config.

```lua
require 'nerveux'.setup()
```

You can override the defaults like so:

```lua
require 'nerveux'.setup {
    --- path to neuron executable (default: neuron in PATH)
    neuron_cmd = "neuron",

    --- no trailing slash, (default: cwd)
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
}
```

## Default Mappings

- `gzz`: Search all your zettels
    - then `<CR>` to edit
    - then `<Tab>` to insert the selected zettel into buffer
- `gzn`: Create a new zettel
- `<CR>`: Follow link under cursor

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
