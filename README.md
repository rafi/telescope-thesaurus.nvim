# Neovim Telescope Thesaurus

> Browse synonyms from [dictionaryapi.com] as a [telescope.nvim] extension.

## Install

Requirements:

- [Neovim] ≥0.9
- [telescope.nvim]
- [dictionaryapi.com] API key

Use your favorite package-manager:

<details>
<summary>With <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

```lua
{
  'rafi/telescope-thesaurus.nvim',
  dependencies = { 'nvim-telescope/telescope.nvim' },
  version = false,
},
```

</details>

<details>
<summary>With <a href="https://github.com/wbthomason/packer.nvim">packer.nvim</a></summary>

```lua
use {
  'rafi/telescope-thesaurus.nvim',
  requires = { 'nvim-telescope/telescope.nvim' }
}
```

</details>

## Setup

Register at [dictionaryapi.com] and get an API key. Set it as
`vim.g.dictionary_api_key` or `DICTIONARY_API_KEY` environment variable.

## Usage

- In normal mode, over a word: `:Telescope thesaurus lookup`
- Query word manually: `:Telescope thesaurus query word=hello`

Bind the lookup command to a keymapping, e.g.:

```lua
vim.keymap.set('n', '<localleader>k', '<cmd>Telescope thesaurus lookup<CR>')
```

Enjoy!

[Neovim]: https://github.com/neovim/neovim
[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
[dictionaryapi.com]: https://www.dictionaryapi.com/
