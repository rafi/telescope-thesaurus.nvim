-- Telescope-thesaurus
-- https://github.com/rafi/telescope-thesaurus.nvim

local M = {}

-- Make new picker and fetch suggestions.
---@private
---@param word string
---@param opts table
M._new_picker = function(word, opts)
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local suggestions = M._get_synonyms(word)

	if not suggestions then
		return
	end

	require('telescope.pickers').new(opts, {
		layout_strategy = 'cursor',
		layout_config = { width = 0.27, height = 0.55 },
		prompt_title = '[ Thesaurus: '.. word ..' ]',
		finder = require('telescope.finders').new_table({ results = suggestions }),
		sorter = require('telescope.config').values.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				if selection == nil then
					require('telescope.utils').__warn_no_selection('builtin.thesaurus')
					return
				end

				action_state.get_current_picker(prompt_bufnr)._original_mode = 'i'
				actions.close(prompt_bufnr)
				vim.cmd('normal! ciw' .. selection[1])
				vim.cmd 'stopinsert'
			end)
			return true
		end,
	})
	:find()
end

-- Lookup words in thesaurus.com
---@private
---@param word string
---@return table?
M._get_synonyms = function(word)
	local url = 'https://www.thesaurus.com/browse/' .. word
	local response = require('plenary.curl').get(url)
	if not (response and response.body) then
		vim.notify('Unable to fetch from thesaurus.com', vim.log.levels.ERROR)
		return
	end

	local json_raw = response.body
		:match('window.INITIAL_STATE = (.*);')
		:gsub('undefined', 'null')
	if not json_raw then
		vim.notify('Unable to parse response', vim.log.levels.ERROR)
		return
	end
	local ok, decoded = pcall(vim.json.decode, json_raw)
	if not ok or decoded == nil or not decoded.searchData then
		vim.notify('Unable to decode response', vim.log.levels.ERROR)
		return
	end
	local data = decoded.searchData.tunaApiData
	if data == vim.NIL then
		local msg = ''
		if decoded.searchData.pageName == 'misspelling' then
			local suggestions = decoded.searchData.spellSuggestionsData
			if #suggestions > 0 then
				msg = 'Did you mean "'..suggestions[1].term..'"?'
				if #suggestions > 1 then
					msg = msg .. ' or "'..suggestions[2].term..'"?'
				end
			end
		end
		vim.notify(msg, vim.log.levels.WARN, { title = 'No definition available' })
		return
	end

	local synonyms = {}
	for _, tab in ipairs(data.posTabs) do
		for _, synonym in ipairs(tab.synonyms) do
			if synonym.term then
				table.insert(synonyms, synonym.term)
			end
		end
		break
	end
	return synonyms
end

--- Lookup word under cursor.
---@param opts table
M.lookup = function(opts)
	local cursor_word = vim.fn.expand('<cword>')
	M._new_picker(cursor_word, opts)
end

--- Query word manually.
---@param opts table<string, string>
M.query = function(opts)
	if not opts.word then
		vim.notify('You must specify a word', vim.log.levels.ERROR)
	end
	M._new_picker(opts.word, opts)
end

return M
