-- Telescope-thesaurus: public API
-- https://github.com/rafi/telescope-thesaurus.nvim

---@class thesaurus.Result
---@field candidates string[] words to pick from
---@field preview string[] markdown lines, empty when there's nothing to show
---@field requery boolean candidates are suggestions for an unknown word
---@field title? string picker title, set when the word wasn't found

---Calls `done` with a result, or with nil and an error message.
---@alias thesaurus.Done fun(result?: thesaurus.Result, err?: string, level?: integer)

---@class thesaurus.Provider
---@field url string base URL of the web API
---@field query fun(word: string, done: thesaurus.Done)
---@field parse_result fun(data: table): string[], string[]

---Buffer text a picked synonym replaces.
---@class thesaurus.Target
---@field buf integer
---@field row integer 0-based line
---@field col integer 0-based byte column
---@field end_col integer end byte column, exclusive
---@field word string text expected in the range

---Options for run(), lookup() and query(): the picker's own options,
---plus the word for query() and a picker that overrides the config.
---@class thesaurus.RunOpts: table
---@field word? string
---@field picker? thesaurus.PickerName

local M = {}

---@param msg string
---@param level? integer
local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.ERROR, { title = 'Thesaurus' })
end

-- Keyword under the cursor, else the next one on the line, like <cword>.
---@return string? word, thesaurus.Target? target
function M.cursor_word()
	local line = vim.api.nvim_get_current_line()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local match =
		vim.fn.matchstrpos(line, [[\k*\%]] .. (cursor[2] + 1) .. [[c\k\+]])
	if match[2] == -1 then
		match = vim.fn.matchstrpos(line, [[\k\+]], cursor[2])
	end
	if match[2] == -1 then
		return
	end
	return match[1],
		{
			buf = vim.api.nvim_get_current_buf(),
			row = cursor[1] - 1,
			col = match[2],
			end_col = match[3],
			word = match[1],
		}
end

-- telescope.setup() options for the extension only apply once telescope
-- loads it.
local function load_telescope_extension()
	local telescope = package.loaded.telescope
	if telescope then
		pcall(function()
			return telescope.extensions.thesaurus
		end)
	end
end

--- Looks up `word` and opens a picker with the results. A "Loading..."
--- popup shows meanwhile. Picking a synonym replaces `target`, if given.
---@param word string
---@param target? thesaurus.Target
---@param opts? thesaurus.RunOpts
function M.run(word, target, opts)
	opts = opts or {}
	load_telescope_extension()
	local cfg = require('thesaurus.config').get()
	local pickers = require('thesaurus.picker')
	local picker, perr = pickers.get(opts.picker or cfg.picker)
	if not picker then
		return notify(perr --[[@as string]])
	end
	local provider = require('thesaurus.provider.' .. cfg.provider) ---@type thesaurus.Provider
	local close_loading = pickers.loading(word, cfg.provider)
	provider.query(word, function(result, err, level)
		close_loading()
		if not result then
			return notify(err or 'Unable to fetch results', level)
		end
		-- Say in the picker that the word wasn't found.
		if #result.candidates == 0 then
			result.title = ('No results for "%s"'):format(word)
		elseif result.requery then
			result.title = ('"%s" not found, did you mean?'):format(word)
		end
		pickers.open(picker, result, target, opts)
	end)
end

--- Looks up the word under the cursor. Picking a synonym replaces it.
---@param opts? thesaurus.RunOpts picker options
function M.lookup(opts)
	local word, target = M.cursor_word()
	if not word then
		return notify('No word under the cursor')
	end
	M.run(word, target, opts)
end

--- Looks up `opts.word`. Picking a synonym yanks it.
---@param opts? thesaurus.RunOpts picker options and the word
function M.query(opts)
	opts = opts or {}
	if not opts.word or vim.trim(opts.word) == '' then
		return notify('You must specify a word')
	end
	M.run(vim.trim(opts.word), nil, opts)
end

return M
