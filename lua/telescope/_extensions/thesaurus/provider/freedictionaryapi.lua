-- Telescope-thesaurus: Free Dictionary API provider
-- https://github.com/rafi/telescope-thesaurus.nvim

local M = {}

local url = 'https://api.dictionaryapi.dev/api/v2/entries/en/'

-- Lookup words
---@private
---@param word string
---@return table?, table, boolean
function M.query(word)
	local data = M._get(word)
	if not data then
		return {}, {}, false
	end

	if data.title and data.title ~= '' then
		return { '' }, { data.message }, false
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
	if not ok or data == nil then
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

	local function add_syns(item)
		for _, syn in ipairs(item.synonyms) do
			if not vim.tbl_contains(synonyms, syn) then
				table.insert(synonyms, syn)
			end
		end
	end

	local function add_ants(item)
		if #item.antonyms > 0 then
			local ants = table.concat(vim.tbl_flatten(item.antonyms), '; ')
			table.insert(p, '  antonyms: ' .. ants)
		end
	end

	for _, result in ipairs(data) do
		for _, meaning in ipairs(result.meanings) do
			if not vim.tbl_contains(synonyms, result.word) then
				table.insert(synonyms, result.word)
			end
			table.insert(
				p,
				'# ' .. result.word .. ' (' .. meaning.partOfSpeech .. ')'
			)
			table.insert(p, '')
			if result.phonetic then
				table.insert(p, '  > ' .. result.phonetic)
			end
			add_syns(meaning)
			add_ants(meaning)
			table.insert(p, '')
			for idx, def in ipairs(meaning.definitions) do
				table.insert(p, '  ' .. idx .. '. ' .. def.definition)
				if def.example then
					vim.list_extend(p, { '', '  "' .. def.example .. '"' })
				end
				add_syns(def)
				add_ants(def)
				table.insert(p, '')
			end
		end
	end

	return synonyms, p
end

return M
