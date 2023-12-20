-- Telescope-thesaurus
-- https://github.com/rafi/telescope-thesaurus.nvim

local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
	error('This plugin requires nvim-telescope/telescope.nvim')
end

local config = require('telescope._extensions.thesaurus.config')
local extension = require('telescope._extensions.thesaurus.lookup')

return telescope.register_extension({
	setup = config.setup,
	exports = {
		lookup = extension.lookup,
		query = extension.query,
	},
})
