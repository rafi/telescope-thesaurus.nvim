-- Telescope-thesaurus: Dictionary API dot com provider
-- https://github.com/rafi/telescope-thesaurus.nvim

local M = {}

local url = 'https://www.dictionaryapi.com/api/v3/references/thesaurus/json/'

-- Lookup words
---@private
---@param word string
---@return table?, table, boolean
function M.query(word)
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

	local data = M._get(word, { key = token })
	if not data then
		return {}, {}, false
	end

	-- Word not found, return suggestions.
	if type(data[1]) == 'string' then
		return data, {}, true
	end

	local words, preview = M.parse_result(data)
	return words, preview, false
end

---@private
function M._get(word, params)
	local response = require('plenary.curl').get(url .. word, { query = params })
	if not (response and response.body) then
		vim.notify('Unable to fetch from ' .. url, vim.log.levels.ERROR)
		return
	end

	local ok, data = pcall(vim.json.decode, response.body)
	if not ok or data == nil or #data == 0 then
		vim.notify(
			'Unable to decode response:' .. response.body,
			vim.log.levels.ERROR
		)
		return
	end
	return data
end

---@private
---@param data table
---@return table?, table
function M.parse_result(data)
	local p = {}
	local synonyms = {}

	for _, result in ipairs(data) do
		-- Collect synonyms
		for _, groups in ipairs(result.meta.syns) do
			for _, term in ipairs(groups) do
				table.insert(synonyms, term)
			end
		end

		-- Parse result and prepare a preview page as markdown.
		local has_stems = #result.meta.stems > 1
		local has_ants = #result.meta.ants > 0
		if result.hwi then
			table.insert(p, '# ' .. result.hwi.hw .. ' (' .. result.fl .. ')')
		end
		table.insert(p, '')
		-- Parse stems as a semi-colon separated list.
		if has_stems then
			table.insert(p, '  ' .. table.concat(result.meta.stems, '; '))
		end
		-- Parse antonyms as a semi-colon separated list with prefix.
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
					-- Convert '{it}word{/it}' to '_word_'
					local example = dt[2][1].t:gsub('{/?it}', '_')
					vim.list_extend(p, { '', '  "' .. example .. '"' })
				end
			end
		end
		-- Recursively find sentence examples throughout the result.
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

	return synonyms, p
end

---@private
function M.mock_get()
	local config = require('telescope._extensions.thesaurus.config')
	local fixture = config.get_fixture_path() / 'dictionaryapi.json'
	return vim.json.decode(fixture:read())
end

return M
