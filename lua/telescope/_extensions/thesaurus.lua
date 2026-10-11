-- Telescope-thesaurus: telescope extension, for :Telescope thesaurus
-- https://github.com/rafi/telescope-thesaurus.nvim

local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
	error('This plugin requires nvim-telescope/telescope.nvim')
end

-- :Telescope thesaurus always opens telescope's picker.
---@param opts? table
---@return thesaurus.RunOpts
local function telescope_opts(opts)
	return vim.tbl_extend('force', opts or {}, { picker = 'telescope' })
end

return telescope.register_extension({
	setup = function(ext_config)
		require('thesaurus.config').setup(ext_config)
	end,
	exports = {
		lookup = function(opts)
			require('thesaurus').lookup(telescope_opts(opts))
		end,
		query = function(opts)
			require('thesaurus').query(telescope_opts(opts))
		end,
	},
})
