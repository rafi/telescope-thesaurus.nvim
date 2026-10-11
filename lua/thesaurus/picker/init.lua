-- Telescope-thesaurus: picker selection, the loading popup and what
-- happens to a picked word
-- https://github.com/rafi/telescope-thesaurus.nvim

---Picker UI. `open` shows the candidates and calls `pick` with the
---chosen word, or nil when nothing was selected.
---@class thesaurus.Picker
---@field name thesaurus.PickerName
---@field available fun(): boolean
---@field open fun(result: thesaurus.Result, pick: fun(word?: string), opts: table)

local M = {}

-- Tried in this order when `picker` is 'auto'.
---@type thesaurus.PickerName[]
M.pickers = { 'snacks', 'telescope' }

---@param msg string
---@param level? integer
local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.ERROR, { title = 'Thesaurus' })
end

-- The picker module for `name`, or the first available one for 'auto'.
---@param name thesaurus.PickerName|'auto'
---@return thesaurus.Picker? picker, string? err
function M.get(name)
	if name ~= 'auto' then
		local picker = require('thesaurus.picker.' .. name) ---@type thesaurus.Picker
		if picker.available() then
			return picker
		end
		return nil, ('%s.nvim is required for picker = %q'):format(name, name)
	end
	for _, candidate in ipairs(M.pickers) do
		local picker = require('thesaurus.picker.' .. candidate) ---@type thesaurus.Picker
		if picker.available() then
			return picker
		end
	end
	return nil, 'snacks.nvim or telescope.nvim is required'
end

--- Shows a "Loading..." popup until the returned function is called.
---@param word string
---@param provider_name string
---@return fun() close
function M.loading(word, provider_name)
	local msg =
		string.format('Loading results for "%s" from %s…', word, provider_name)
	local width =
		math.max(vim.api.nvim_strwidth(msg) + 4, math.floor(vim.o.columns / 2))
	width = math.min(width, vim.o.columns - 2)
	local pad = math.max(0, math.floor((width - vim.api.nvim_strwidth(msg)) / 2))
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(
		buf,
		0,
		-1,
		false,
		{ '', string.rep(' ', pad) .. msg }
	)
	vim.bo[buf].bufhidden = 'wipe'
	local winid = vim.api.nvim_open_win(buf, false, {
		relative = 'editor',
		row = math.floor((vim.o.lines - 5) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = 3,
		style = 'minimal',
		-- 'winborder' applies when set. Its default draws no border.
		border = vim.o.winborder == '' and 'rounded' or nil,
		focusable = false,
		noautocmd = true,
	})
	return function()
		if not vim.api.nvim_win_is_valid(winid) then
			return
		end
		local ok, err = pcall(vim.api.nvim_win_close, winid, true)
		if not ok then
			notify(
				('Unable to close window %s: %s'):format(tostring(winid), err),
				vim.log.levels.WARN
			)
		end
	end
end

-- Replaces the target text with `word`, unless the text changed.
---@param target thesaurus.Target
---@param word string
local function replace(target, word)
	local t = target
	local ok, text =
		pcall(vim.api.nvim_buf_get_text, t.buf, t.row, t.col, t.row, t.end_col, {})
	if not ok or text[1] ~= t.word then
		return notify(
			('"%s" changed, not replacing it'):format(t.word),
			vim.log.levels.WARN
		)
	end
	vim.api.nvim_buf_set_text(t.buf, t.row, t.col, t.row, t.end_col, { word })
	local win = vim.fn.bufwinid(t.buf)
	if win ~= -1 then
		vim.api.nvim_win_set_cursor(win, { t.row + 1, t.col })
	end
end

-- Yanks `word` into v:register.
---@param word string
local function yank(word)
	vim.fn.setreg(vim.v.register, word)
	notify(('Yanked "%s"'):format(word), vim.log.levels.INFO)
end

--- Opens `picker` with the result. A picked suggestion is looked up again,
--- else the synonym replaces the target, or is yanked without a target.
---@param picker thesaurus.Picker
---@param result thesaurus.Result
---@param target? thesaurus.Target
---@param opts thesaurus.RunOpts
function M.open(picker, result, target, opts)
	-- Only the picker's own options go to the picker.
	local picker_opts = vim.deepcopy(opts)
	picker_opts.word, picker_opts.picker = nil, nil
	picker.open(result, function(word)
		if word == nil then
			return notify('Nothing selected', vim.log.levels.WARN)
		end
		if result.requery then
			require('thesaurus').run(word, target, opts)
		elseif target then
			replace(target, word)
		else
			yank(word)
		end
	end, picker_opts)
end

return M
