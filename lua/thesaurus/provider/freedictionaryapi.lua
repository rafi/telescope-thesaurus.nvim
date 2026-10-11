-- Telescope-thesaurus: Free Dictionary API provider
-- https://github.com/rafi/telescope-thesaurus.nvim

local http = require('thesaurus.http')

local M = {}

M.url = 'https://api.dictionaryapi.dev/api/v2/entries/en/'

-- Lookup words
---@param word string
---@param done thesaurus.Done
function M.query(word, done)
	http.get(M.url .. http.encode(word), function(res)
		-- Unknown words are a 404 with a JSON title and message. Return no
		-- candidates, so the picker says so.
		local data = res.data
		if res.status == 404 and type(data) == 'table' and data.message then
			return done({ candidates = {}, preview = {}, requery = false })
		end
		if res.err then
			return done(nil, res.err)
		end
		local ok, words, preview = pcall(M.parse_result, data)
		if not ok then
			return done(nil, 'Unexpected response from dictionaryapi.dev: ' .. words)
		end
		done({ candidates = words, preview = preview, requery = false })
	end)
end

---@param data table decoded response
---@return string[] synonyms, string[] preview
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
			local ants = vim.iter(item.antonyms):flatten(math.huge):totable()
			table.insert(p, '  antonyms: ' .. table.concat(ants, '; '))
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
