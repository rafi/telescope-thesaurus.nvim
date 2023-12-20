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
	config.mappings = vim.tbl_deep_extend(
		'force',
		config.mappings,
		require('telescope.config').values.mappings
	)
	config = vim.tbl_deep_extend('force', config, opts)
end

local extension = require('telescope._extensions.thesaurus.lookup')

-- Register plugin
return telescope.register_extension({
	setup = setup,
	exports = {
		lookup = extension.lookup,
		query = extension.query,
	},
})
