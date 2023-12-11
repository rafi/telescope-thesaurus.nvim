-- Telescope-thesaurus
-- https://github.com/rafi/telescope-thesaurus.nvim

local previewers = require('telescope.previewers')

local M = {}

-- Make new picker and fetch suggestions.
---@private
---@param word string
---@param opts table
M._new_picker = function(word, opts)
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local candidates, text, found_term = M._get_synonyms(word)

	if not candidates then
		vim.notify('Unable to fetch synonyms', vim.log.levels.ERROR)
		return
	end

	local previewer = nil
	local width = 0.27
	if found_term then
		previewer = M._preview(text)
		width = 0.5
	end

	require('telescope.pickers')
		.new(opts, {
			layout_strategy = 'cursor',
			layout_config = { width = width, height = 0.55 },
			prompt_title = '',
			finder = require('telescope.finders').new_table({ results = candidates }),
			sorter = require('telescope.config').values.generic_sorter(opts),
			previewer = previewer,
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					if selection == nil then
						require('telescope.utils').__warn_no_selection('builtin.thesaurus')
						return
					end

					actions.close(prompt_bufnr)
					if not found_term then
						M._new_picker(selection[1], opts)
						return
					end
					vim.cmd('normal! ciw' .. selection[1])
					vim.cmd('stopinsert')
				end)
				return true
			end,
		})
		:find()
end

-- Previewer for telescope
---@param text table lines to fill preview
---@return table
M._preview = function(text)
	return previewers.new_buffer_previewer({
		title = 'Thesaurus',
		keep_last_buf = false,
		define_preview = function(self, _, _)
			local winid = self.state.winid
			local bufnr = self.state.bufnr
			vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, text)
			vim.api.nvim_set_option_value('number', false, { win = winid })
			vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
			vim.api.nvim_set_option_value('wrap', true, { win = winid })
			vim.api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })
		end,
	})
end

-- Lookup words in www.dictionaryapi.com
---@private
---@param word string
---@return table?, table, boolean
M._get_synonyms = function(word)
	local token = vim.g.dictionary_api_key
	if not token then
		token = vim.env.DICTIONARY_API_KEY
	end
	if not token then
		vim.notify(
			'Set dictionaryapi.com token as vim.g.dictionary_api_key or $DICTIONARY_API_KEY',
			vim.log.levels.ERROR
		)
		return {}, {}, false
	end

	local url = 'https://www.dictionaryapi.com/api/v3/references/thesaurus/json/'
		.. word
	local response = require('plenary.curl').get(url, { query = { key = token } })
	if not (response and response.body) then
		vim.notify('Unable to fetch from dictionaryapi.com', vim.log.levels.ERROR)
		return {}, {}, false
	end

	local ok, data = pcall(vim.json.decode, response.body)
	if not ok or data == nil or #data == 0 then
		vim.notify('Unable to decode response', vim.log.levels.ERROR)
		return {}, {}, false
	end

	-- Word not found, return suggestions.
	if type(data[1]) == 'string' then
		return data, {}, false
	end

	local p = {}
	local synonyms = {}

	for _, result in ipairs(data) do
		-- Collect synonyms
		for _, groups in ipairs(result.meta.syns) do
			for _, term in ipairs(groups) do
				table.insert(synonyms, term)
			end
		end

		-- Construct preview page text
		local has_stems = #result.meta.stems > 1
		local has_ants = #result.meta.ants > 0
		if result.hwi then
			table.insert(p, '# ' .. result.hwi.hw .. ' (' .. result.fl .. ')')
		end
		table.insert(p, '')
		if has_stems then
			table.insert(p, '  ' .. table.concat(result.meta.stems, '; '))
		end
		if has_ants then
			local ants = table.concat(vim.tbl_flatten(result.meta.ants), '; ')
			table.insert(p, '  antonyms: ' .. ants)
		end
		if has_stems or has_ants then
			table.insert(p, '')
		end
		for idx, shortdef in ipairs(result.shortdef) do
			table.insert(p, '  ' .. idx .. '. ' .. shortdef)
		end

		local function insert_vis(term)
			for _, dt in ipairs(term[2].dt) do
				if dt[1] == 'vis' then
					local example = dt[2][1].t:gsub('{/?it}', '_')
					vim.list_extend(p, { '', '  "' .. example .. '"' })
				end
			end
		end
		local function find_sentences(list)
			for _, term in ipairs(list.sseq or list) do
				if #term > 1 and term[2].dt then
					insert_vis(term)
				else
					find_sentences(term)
				end
			end
		end
		find_sentences(result.def)
		table.insert(p, '')
	end

	return synonyms, p, true
end

-- Lookup words in thesaurus.com
---@deprecated
---@private
---@param word string
---@return table?
M._get_synonyms_deprecated = function(word)
	local url = 'https://www.thesaurus.com/browse/' .. word
	local response = require('plenary.curl').get(url)
	if not (response and response.body) then
		vim.notify('Unable to fetch from thesaurus.com', vim.log.levels.ERROR)
		return
	end

	local json_raw =
		response.body:match('var slotConfigs = (.*);'):gsub('undefined', 'null')
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
				msg = 'Did you mean "' .. suggestions[1].term .. '"?'
				if #suggestions > 1 then
					msg = msg .. ' or "' .. suggestions[2].term .. '"?'
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
	local cursor_word = vim.fn.expand('<cword>') --[[@as string]]
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
