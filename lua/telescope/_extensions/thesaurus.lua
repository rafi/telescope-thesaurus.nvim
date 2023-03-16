-- Telescope-thesaurus
-- https://github.com/rafi/telescope-thesaurus.nvim

local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
	error('This plugin requires nvim-telescope/telescope.nvim')
end

local config = {
	mappings = {},
}

-- Setup extension config
local setup = function(opts)
	config.mappings =
		vim.tbl_deep_extend('force', config.mappings, require('telescope.config').values.mappings)
	config = vim.tbl_deep_extend('force', config, opts)
end

-- Sub-commands
local lookup = require('telescope._extensions.thesaurus.lookup').lookup
local query = require('telescope._extensions.thesaurus.lookup').query

-- Register plugin
return telescope.register_extension({
	setup = setup,
	exports = {
		lookup = lookup,
		query = query,
	},
})
