-- Telescope-thesaurus: Dictionary API dot com provider
-- https://github.com/rafi/telescope-thesaurus.nvim

local http = require('thesaurus.http')

local M = {}

M.url = 'https://www.dictionaryapi.com/api/v3/references/thesaurus/json/'

-- Lookup words
---@param word string
---@param done thesaurus.Done
function M.query(word, done)
	local token = require('thesaurus.config').api_key()
	if not token then
		return done(
			nil,
			'Set a dictionaryapi.com key as vim.g.thesaurus.api_key or $DICTIONARY_API_KEY'
		)
	end
	local url = http.url(M.url .. http.encode(word), { key = token })
	http.get(url, function(res)
		if res.err then
			return done(nil, res.err)
		end
		local data = res.data
		if type(data) ~= 'table' then
			return done(nil, 'Unexpected response from dictionaryapi.com')
		end
		-- Word not found, return suggestions.
		if type(data[1]) == 'string' then
			return done({ candidates = data, preview = {}, requery = true })
		end
		local ok, words, preview = pcall(M.parse_result, data)
		if not ok then
			return done(nil, 'Unexpected response from dictionaryapi.com: ' .. words)
		end
		done({ candidates = words, preview = preview, requery = false })
	end)
end

---@param data table decoded response
---@return string[] synonyms, string[] preview
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
			local ants = vim.iter(result.meta.ants):flatten(math.huge):totable()
			table.insert(p, '  antonyms: ' .. table.concat(ants, '; '))
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

return M
