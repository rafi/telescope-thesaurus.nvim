-- telescope-thesaurus.nvim entry point: defines :Thesaurus and
-- <Plug>(ThesaurusLookup). Requires nothing until used.
-- https://github.com/rafi/telescope-thesaurus.nvim

if vim.g.loaded_thesaurus then
	return
end
vim.g.loaded_thesaurus = true

---@type table<string, fun(args: string[])>
local subcommands = {
	lookup = function()
		require('thesaurus').lookup()
	end,
	query = function(args)
		require('thesaurus').query({ word = table.concat(args, ' ') })
	end,
}

vim.api.nvim_create_user_command('Thesaurus', function(opts)
	local name = opts.fargs[1] or 'lookup'
	local sub = subcommands[name]
	if not sub then
		vim.notify('thesaurus: unknown subcommand ' .. name, vim.log.levels.ERROR)
		return
	end
	sub(vim.list_slice(opts.fargs, 2))
end, {
	nargs = '*',
	desc = 'Thesaurus: lookup (word under cursor), query {word}',
	complete = function(lead, line)
		-- Only the first argument has completions.
		if line:match('^%S+%s+%S+%s') then
			return {}
		end
		local names = vim.tbl_keys(subcommands)
		table.sort(names)
		return vim.tbl_filter(function(name)
			return vim.startswith(name, lead)
		end, names)
	end,
})

vim.keymap.set('n', '<Plug>(ThesaurusLookup)', subcommands.lookup, {
	desc = 'Thesaurus: look up the word under the cursor',
})
