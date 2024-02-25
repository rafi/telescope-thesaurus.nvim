# Neovim Telescope Thesaurus

> Browse synonyms & definitions from multiple providers as a [telescope.nvim]
> extension.

## Screenshot

![Thesaurus screenshot](http://rafi.io/img/project/telescope-thesaurus.nvim/dictionaryapi-popup.png)

## Install

Requirements:

- [Neovim] ≥0.9
- [telescope.nvim]

Use your favorite package-manager:

<details>
<summary>With <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

```lua
{
  'nvim-telescope/telescope.nvim',
  dependencies = { 'rafi/telescope-thesaurus.nvim' },
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

Supported providers:

- `dictionaryapi` ([dictionaryapi.com]) — Default, **token needed**. (Best results)
- `datamuse` ([datamuse.com])
- `freedictionaryapi` ([dictionaryapi.dev])

Register at [dictionaryapi.com] and get an API key (type: `Collegiate Thesaurus`). Set it as
`vim.g.dictionary_api_key` or `DICTIONARY_API_KEY` environment variable.

To set a different provider, set options from Telescope config. If you're using
lazy.nvim, here's an example:

```lua
{
  'nvim-telescope/telescope.nvim',
  opts = {
    extensions = {
      thesaurus = {
        provider = 'datamuse',
      },
    },
  },
}
```

## Usage

- In normal mode, when cursor over a word: `:Telescope thesaurus lookup`
- Query word manually: `:Telescope thesaurus query word=hello`

Bind the lookup command to a key-mapping, e.g.:

```lua
vim.keymap.set('n', '<localleader>k', '<cmd>Telescope thesaurus lookup<CR>')
```

Enjoy!

[Neovim]: https://github.com/neovim/neovim
[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
[dictionaryapi.com]: https://www.dictionaryapi.com/
[datamuse.com]: https://www.datamuse.com/api/
[dictionaryapi.dev]: https://dictionaryapi.dev/
