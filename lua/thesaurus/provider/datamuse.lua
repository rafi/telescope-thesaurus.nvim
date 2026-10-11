-- Telescope-thesaurus: Datamuse provider
-- https://github.com/rafi/telescope-thesaurus.nvim

local http = require('thesaurus.http')

local M = {}

M.url = 'https://api.datamuse.com/words'

-- Lookup words
---@param word string
---@param done thesaurus.Done
function M.query(word, done)
	http.get(http.url(M.url, { max = 100, ml = word }), function(res)
		if res.err then
			return done(nil, res.err)
		end
		local ok, words, preview = pcall(M.parse_result, res.data)
		if not ok then
			return done(nil, 'Unexpected response from datamuse.com: ' .. words)
		end
		done({ candidates = words, preview = preview, requery = false })
	end)
end

---@param data table decoded response
---@return string[] synonyms, string[] preview
function M.parse_result(data)
	local synonyms = {}
	for _, item in ipairs(data) do
		table.insert(synonyms, item.word)
	end
	return synonyms, {}
end

return M
