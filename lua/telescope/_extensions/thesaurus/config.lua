-- Telescope-thesaurus: config
-- https://github.com/rafi/telescope-thesaurus.nvim

local M = {}

local providers = {
	'dictionaryapi',
	'datamuse',
	'freedictionaryapi',
}

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

M.get_fixture_path = function()
	local script_path = vim.fs.dirname(debug.getinfo(1).source:sub(2))
	local path = require('plenary.path'):new(script_path)
	path = path:parent():parent():parent()
	path = path / 'tests' / 'fixtures' / 'provider'
	return path
end

return M
