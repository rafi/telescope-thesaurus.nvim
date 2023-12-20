local M = {}

local url = 'https://api.datamuse.com/words?max=100&ml='

-- Lookup words
---@private
---@param word string
---@return table?, table, boolean
function M.query(word)
	local data = M._get(word)
	if not data then
		return {}, {}, false
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

	for _, item in ipairs(data) do
		table.insert(synonyms, item.word)
	end

	return synonyms, p
end

---@private
function M.mock_get()
	local config = require('telescope._extensions.thesaurus.config')
	local fixture = config.get_fixture_path() / 'datamuse.json'
	return vim.json.decode(fixture:read())
end

return M
