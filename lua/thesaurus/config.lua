-- Telescope-thesaurus: config
-- https://github.com/rafi/telescope-thesaurus.nvim

---@alias thesaurus.ProviderName 'dictionaryapi'|'datamuse'|'freedictionaryapi'
---@alias thesaurus.PickerName 'snacks'|'telescope'

---@class thesaurus.Config
---@field provider thesaurus.ProviderName Where words are looked up.
---@field picker thesaurus.PickerName|'auto' Picker UI. 'auto' uses snacks.nvim, else telescope.nvim.
---@field api_key? string dictionaryapi.com key, else $DICTIONARY_API_KEY.

---User options. Every field is optional.
---@class (partial) thesaurus.Opts: thesaurus.Config

---@type thesaurus.Opts?
vim.g.thesaurus = vim.g.thesaurus

local M = {}

---@type thesaurus.ProviderName[]
M.providers = { 'dictionaryapi', 'datamuse', 'freedictionaryapi' }

---@type (thesaurus.PickerName|'auto')[]
M.picker_names = { 'auto', 'snacks', 'telescope' }

---@type thesaurus.Config
M.defaults = { provider = 'dictionaryapi', picker = 'auto' }

-- Options from telescope.setup({ extensions = { thesaurus = ... } }).
local telescope_opts ---@type table?

local resolved ---@type thesaurus.Config?

---@param opts table partial config
---@param prefix string field path shown in errors
---@return boolean ok, string? err
function M.validate(opts, prefix)
	local ok, err = pcall(function()
		vim.validate('provider', opts.provider, function(v)
			return v == nil or vim.tbl_contains(M.providers, v)
		end, 'one of ' .. table.concat(M.providers, ', '))
		vim.validate('picker', opts.picker, function(v)
			return v == nil or vim.tbl_contains(M.picker_names, v)
		end, 'one of ' .. table.concat(M.picker_names, ', '))
		vim.validate('api_key', opts.api_key, 'string', true)
	end)
	if ok then
		return true
	end
	return false, prefix .. '.' .. tostring(err):gsub('^[^\n]-:%d+: ', '')
end

-- Keys that aren't config fields.
---@param opts table
---@return string[]
function M.unknown_keys(opts)
	local keys = {}
	for key in pairs(opts) do
		if not vim.tbl_contains({ 'provider', 'picker', 'api_key' }, key) then
			table.insert(keys, tostring(key))
		end
	end
	table.sort(keys)
	return keys
end

-- Stores the telescope extension options. Called by telescope when it
-- loads the extension.
---@param opts? table
function M.setup(opts)
	telescope_opts = opts
	resolved = nil
end

-- Source tables and their field paths, lowest priority first.
---@return { opts: any, prefix: string }[]
function M.sources()
	return {
		{ opts = telescope_opts, prefix = 'telescope extensions.thesaurus' },
		{ opts = vim.g.thesaurus, prefix = 'vim.g.thesaurus' },
	}
end

-- Defaults, then telescope extension options, then vim.g.thesaurus. An
-- invalid source is left out and its error returned.
---@return thesaurus.Config cfg, string[] errors
function M.resolve()
	local cfg = vim.deepcopy(M.defaults)
	local errors = {}
	for _, source in ipairs(M.sources()) do
		local opts, err = source.opts, nil
		if opts ~= nil and type(opts) ~= 'table' then
			err = ('%s: expected table, got %s'):format(source.prefix, type(opts))
		elseif opts ~= nil then
			local ok
			ok, err = M.validate(opts, source.prefix)
			if ok then
				cfg = vim.tbl_deep_extend('force', cfg, opts)
			end
		end
		if err then
			table.insert(errors, err)
		end
	end
	return cfg, errors
end

-- Resolved config, read on first use so vim.g.thesaurus can be set
-- anywhere. Errors are reported once.
---@return thesaurus.Config
function M.get()
	if resolved then
		return resolved
	end
	local cfg, errors = M.resolve()
	for _, err in ipairs(errors) do
		vim.notify(('thesaurus: %s; ignoring it'):format(err), vim.log.levels.ERROR)
	end
	resolved = cfg
	return cfg
end

-- dictionaryapi.com key: config, then $DICTIONARY_API_KEY, then the
-- deprecated vim.g.dictionary_api_key.
---@param cfg? thesaurus.Config defaults to get()
---@return string?
function M.api_key(cfg)
	local key = (cfg or M.get()).api_key or vim.env.DICTIONARY_API_KEY
	if key and key ~= '' then
		return key
	end
	if vim.g.dictionary_api_key then
		vim.deprecate(
			'vim.g.dictionary_api_key',
			'vim.g.thesaurus.api_key',
			'2.0',
			'telescope-thesaurus.nvim'
		)
		return vim.g.dictionary_api_key
	end
end

return M
