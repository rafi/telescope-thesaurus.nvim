-- Telescope-thesaurus: config
-- https://github.com/rafi/telescope-thesaurus.nvim

local M = {}

local providers = { 'dictionaryapi', 'freedictionaryapi' }

local default_config = {
	mappings = {},
	provider = providers[1],
}

local current_config = default_config

M.get = function()
	return current_config
end

M.setup = function(user_config)
	local cfg = default_config
	cfg.mappings = vim.tbl_deep_extend(
		'force',
		cfg.mappings,
		require('telescope.config').values.mappings
	)
	cfg = vim.tbl_deep_extend('force', cfg, user_config)
	current_config = cfg
end

return M
