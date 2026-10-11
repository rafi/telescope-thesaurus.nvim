# Neovim Thesaurus with Snacks/Telescope

> Browse synonyms & definitions from multiple providers in a [snacks.nvim]
> or [telescope.nvim] picker.

## Screenshot

![Thesaurus screenshot](https://raw.githubusercontent.com/rafi/assets/master/repo/telescope-thesaurus.nvim/dictionaryapi-popup.png)

## Install

Requirements:

- [Neovim] ≥0.11
- [snacks.nvim] or [telescope.nvim]
- `curl`

Use your favorite package-manager:

<details>
<summary>With vim.pack (Neovim 0.12+)</summary>

```lua
vim.pack.add({
  'https://github.com/folke/snacks.nvim',
  'https://github.com/rafi/telescope-thesaurus.nvim',
})
```

</details>

<details>
<summary>With <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

```lua
{ 'rafi/telescope-thesaurus.nvim', dependencies = { 'folke/snacks.nvim' } },
```

</details>

<details>
<summary>With <a href="https://github.com/wbthomason/packer.nvim">packer.nvim</a></summary>

```lua
use { 'rafi/telescope-thesaurus.nvim', requires = { 'folke/snacks.nvim' } }
```

</details>

## Setup

No `setup()` call is needed. Options go in `vim.g.thesaurus`, read on first
use:

```lua
vim.g.thesaurus = {
  provider = 'freedictionaryapi', -- default: 'dictionaryapi'
  picker = 'telescope', -- default: 'auto', snacks if installed, else telescope
  api_key = nil, -- dictionaryapi.com key, default: $DICTIONARY_API_KEY
}
```

Supported providers:

- `dictionaryapi` ([dictionaryapi.com]): default, **key needed** (best results)
- `datamuse` ([datamuse.com])
- `freedictionaryapi` ([dictionaryapi.dev])

Register at [dictionaryapi.com] and get an API key (type: "Collegiate
Thesaurus"). Set it as `vim.g.thesaurus.api_key` or the `DICTIONARY_API_KEY`
environment variable. `vim.g.dictionary_api_key` still works but is deprecated.

Options from the telescope config also work. `vim.g.thesaurus` wins over
them:

```lua
require('telescope').setup({
  extensions = {
    thesaurus = { provider = 'datamuse' },
  },
})
```

Run `:checkhealth thesaurus` to check curl, the options, the picker and the
key.

## Usage

Map the lookup to a key, e.g.:

```lua
vim.keymap.set('n', '<localleader>k', '<Plug>(ThesaurusLookup)')
```

See `:h thesaurus` for details.

- Look up the word under the cursor: `:Thesaurus lookup`, `<Plug>(ThesaurusLookup)`
  or `:Telescope thesaurus lookup`. Picking a synonym replaces the word.
- Query a word: `:Thesaurus query hello` or
  `:Telescope thesaurus query word=hello`. Picking a word yanks it.

`:Telescope thesaurus` always opens a telescope picker.

For an unknown word, the picker lists suggestions. Picking one looks it up.

[Neovim]: https://github.com/neovim/neovim
[snacks.nvim]: https://github.com/folke/snacks.nvim
[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
[dictionaryapi.com]: https://www.dictionaryapi.com/
[datamuse.com]: https://www.datamuse.com/api/
[dictionaryapi.dev]: https://dictionaryapi.dev/
