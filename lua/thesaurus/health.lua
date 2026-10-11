-- Telescope-thesaurus: :checkhealth thesaurus
-- https://github.com/rafi/telescope-thesaurus.nvim

local M = {}

function M.check()
	local health = vim.health
	health.start('Requirements')
	if vim.fn.has('nvim-0.11') == 1 then
		health.ok('Neovim 0.11+')
	else
		health.error('Neovim 0.11+ required')
	end
	if vim.fn.executable('curl') == 1 then
		health.ok('curl is installed')
	else
		health.error('curl not found in $PATH')
	end

	health.start('Configuration')
	local Config = require('thesaurus.config')
	local cfg, errors = Config.resolve()
	for _, err in ipairs(errors) do
		health.error(err, 'Fix it. The value is ignored until then')
	end
	if #errors == 0 then
		health.ok('Options are valid')
	end
	for _, source in ipairs(Config.sources()) do
		if type(source.opts) == 'table' then
			for _, key in ipairs(Config.unknown_keys(source.opts)) do
				health.warn(('%s.%s is not an option'):format(source.prefix, key))
			end
		end
	end
	health.info('Provider: ' .. cfg.provider)
	local picker, perr = require('thesaurus.picker').get(cfg.picker)
	if picker then
		health.ok(('Picker: %s (picker = %q)'):format(picker.name, cfg.picker))
	else
		health.error(
			perr --[[@as string]],
			'Install one, or set vim.g.thesaurus.picker'
		)
	end
	if cfg.provider == 'dictionaryapi' then
		if Config.api_key(cfg) then
			health.ok('dictionaryapi.com key is set')
		else
			health.error(
				'dictionaryapi.com key is missing',
				'Set vim.g.thesaurus.api_key or $DICTIONARY_API_KEY, or use another provider'
			)
		end
	end
end

return M
