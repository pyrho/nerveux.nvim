# Nerveux

*Work in progress*

A neovim lua plugin to interact with [neuron](http://neuron.zettel.page).

## Install
```vimL
" vim-plug 
Plug 'nvim-lua/plenary.nvim'
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
    -- 
    neuron_cmd = "neuron"

    -- no trailing slash, defaults to current directory
    neuron_dir = "/my/zettel/root/dir",

    -- Use the cache, significantly faster
    use_cache = true,

    -- start the neuron daemon to keep the cache up to date
    start_daemon = true,

    -- show zettel titles inline as virtual text
    virtual_titles = true

    -- Automatically create mappings
    create_default_mappings = true,

    -- The Highlight Group used for the inline zettel titles (virtual text)
    virtual_title_hl = Special
}
```

## Default Mappings

gzz
: Search all your zettels

gzn
: Create a new zettel

<CR>
: Follow link under cursor

## Motivation

So far the [history](https://github.com/ihsanturk/neuron.vim) of vim
[plugins](https://github.com/fiatjaf/neuron.vim) for neuron [has](https://github.com/oberblastmeister/neuron.nvim) been very
[spotty](https://github.com/chiefnoah/neuron-v2.vim).

Now it's my turn to create abandonware (:) (and learn how to build lua neovim
plugins !)

A lot of the code is ~~borrowed~~ blatantly stolen from [neuron.nvim](https://github.com/oberblastmeister/neuron.nvim).
