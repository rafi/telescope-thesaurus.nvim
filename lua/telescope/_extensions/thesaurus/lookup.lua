-- Telescope-thesaurus: lookup
-- https://github.com/rafi/telescope-thesaurus.nvim

local action_state = require('telescope.actions.state')
local actions = require('telescope.actions')
local finders = require('telescope.finders')
local popup = require('plenary.popup')
local telescope_config = require('telescope.config')

local M = {}

--- Runs the query and show a "loading..." popup while waiting for results.
---@private
---@param word string input word
---@param opts table options
---@param picker_fn function telescope picker function
---@return uv_timer_t
function M.run(word, opts, picker_fn)
	local config = require('telescope._extensions.thesaurus.config')
	local row = math.floor((vim.o.lines - 5) / 2)
	local width = math.floor(vim.o.columns / 2)
	local col = math.floor((vim.o.columns - width) / 2)
	local provider_name = config.get().provider
	local msg =
		string.format('Loading results for "%s" from %s…', word, provider_name)
	for _ = 1, (width - #msg) / 2, 1 do
		msg = ' ' .. msg
	end
	local prompt_win, prompt_opts = popup.create(msg, {
		border = opts.border ~= nil and opts.border or true,
		borderchars = opts.borderchars
			or { '─', '│', '─', '│', '╭', '╮', '╯', '╰' },
		width = width,
		height = 5,
		col = col,
		line = row,
	})
	local scope = { scope = 'local', win = prompt_win }
	vim.api.nvim_set_option_value('winhl', 'Normal:TelescopeNormal', scope)
	vim.api.nvim_set_option_value('winblend', 0, scope)
	local prompt_border_win = prompt_opts.border and prompt_opts.border.win_id
	if prompt_border_win then
		vim.api.nvim_set_option_value(
			'winhl',
			'Normal:TelescopePromptBorder',
			{ scope = 'local', win = prompt_border_win }
		)
	end
	return vim.defer_fn(function()
		local provider = M.get_provider(provider_name)
		if not provider then
			pcall(vim.api.nvim_win_close, prompt_win, true)
			return M.error_no_provider(provider_name)
		end
		local ok, candidates, preview, should_requery = pcall(provider.query, word)
		if not pcall(vim.api.nvim_win_close, prompt_win, true) then
			M.warning_window(prompt_win)
		end
		if not (candidates and ok) then
			return M.error_no_results(candidates)
		end
		picker_fn(candidates, preview, should_requery, opts)
	end, 10)
end

-- Import and return provider by name.
---@private
---@param name string
---@return table?
function M.get_provider(name)
	local ok, p =
		pcall(require, 'telescope._extensions.thesaurus.provider.' .. name)

	if not (ok and p) then
		return nil
	end
	return p
end

-- Make new picker and fetch suggestions.
---@private
---@param candidates table
---@param preview_content table
---@param should_requery boolean
---@param opts table
function M.new_picker(candidates, preview_content, should_requery, opts)
	local previewer = nil
	local width = 0.27
	local height = 0.55
	if #preview_content > 1 then
		previewer = M.previewer(preview_content)
		width = 0.5
	end

	require('telescope.pickers')
		.new(opts, {
			layout_strategy = 'cursor',
			layout_config = {
				prompt_position = 'top',
				width = width,
				height = height,
			},
			prompt_title = '',
			results_title = '',
			finder = finders.new_table({ results = candidates }),
			sorter = telescope_config.values.generic_sorter(opts),
			previewer = previewer,
			-- Default action. Replace word under cursor or open a new picker.
			attach_mappings = function()
				-- When no preview content was provided, the candidates were
				-- suggestions for an unknown word. So once a suggestion was selected,
				-- open a new picker with fresh results for the selected word.
				if should_requery then
					actions.select_default:replace(M.action_query(opts))
				else
					actions.select_default:replace(M.action_replace)
				end
				return true
			end,
		})
		:find()
end

-- Replace word under cursor with selected synonym.
function M.action_replace(prompt_bufnr)
	actions.close(prompt_bufnr)
	local selection = action_state.get_selected_entry()
	if selection == nil then
		return M.error_no_selection()
	end
	vim.cmd('normal! ciw' .. selection[1])
	vim.cmd('stopinsert')
end

-- Use selected word to re-query thesaurus.
function M.action_query(opts)
	return function(prompt_bufnr)
		actions.close(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if selection == nil then
			return M.error_no_selection()
		end
		opts.word = selection[1]
		M.query(opts)
	end
end

-- Errors and warnings

---@private
function M.error_no_selection()
	require('telescope.utils').__warn_no_selection('builtin.thesaurus')
end

---@private
function M.error_no_provider(name)
	vim.notify('Invalid provider: ' .. name, vim.log.levels.ERROR)
end

---@private
function M.error_no_results(err)
	vim.notify(
		'Unable to fetch results: ' .. vim.inspect(err),
		vim.log.levels.ERROR
	)
end

---@private
function M.error_no_word()
	vim.notify('You must specify a word', vim.log.levels.ERROR)
end

---@private
function M.warning_window(winid)
	vim.notify('Unable to close window: ' .. string(winid), vim.log.levels.WARN)
end

-- Previewer for telescope
---@private
---@param text table lines to fill preview
---@return table
function M.previewer(text)
	return require('telescope.previewers').new_buffer_previewer({
		keep_last_buf = true,
		define_preview = function(self, _, _)
			local bufnr = self.state.bufnr
			vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, text)
			local winid = self.state.winid
			vim.api.nvim_set_option_value('number', false, { win = winid })
			vim.api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })
			vim.api.nvim_set_option_value('wrap', true, { win = winid })
		end,
	})
end

-- Public API commands

--- Lookup word under cursor.
---@param opts table
function M.lookup(opts)
	opts = opts or {}
	local cursor_word = vim.fn.expand('<cword>') --[[@as string]]
	M.run(cursor_word, opts, M.new_picker)
end

--- Query word manually.
---@param opts table<string, string>
function M.query(opts)
	opts = opts or {}
	if not opts.word then
		return M.error_no_word()
	end
	M.run(opts.word, opts, M.new_picker)
end

return M
