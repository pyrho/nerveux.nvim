# Nerveux

*Work in progress*

A neovim lua plugin to interact with [neuron](http://neuron.zettel.page).

## Install
```vimL
" vim-plug 
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
    -- path to neuron executable (default: neuron in PATH)
    neuron_cmd = "neuron"

    -- no trailing slash, (default: cwd)
    neuron_dir = "/my/zettel/root/dir",

    -- Use the cache, significantly faster (default: false)
    use_cache = true,

    -- start the neuron daemon to keep the cache up to date (default: false)
    start_daemon = true,

    -- show zettel titles inline as virtual text (default: false)
    virtual_titles = true

    -- Automatically create mappings (default: false)
    create_default_mappings = true,

    -- The Highlight Group used for the inline zettel titles (default: Special)
    virtual_title_hl = "Special"

    -- `kill -9` the pid of the daemon at exit (VimPreLeave), only valid is
    -- start_daemon is true (default: false)
    kill_daemon_at_exit = true
}
```

## Default Mappings

`gzz`: Search all your zettels

`gzn`: Create a new zettel

`<CR>`: Follow link under cursor

## Motivation

So far the [history](https://github.com/ihsanturk/neuron.vim) of vim
[plugins](https://github.com/fiatjaf/neuron.vim) for neuron [has](https://github.com/oberblastmeister/neuron.nvim) been very
[spotty](https://github.com/chiefnoah/neuron-v2.vim).

Now it's my turn to create abandonware (:) (and learn how to build lua neovim
plugins !)

A lot of the code is ~~borrowed~~ blatantly stolen from [neuron.nvim](https://github.com/oberblastmeister/neuron.nvim).
