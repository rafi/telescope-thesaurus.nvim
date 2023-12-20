-- Telescope-thesaurus
-- https://github.com/rafi/telescope-thesaurus.nvim

local M = {}

M.providers = { 'dictionaryapi' }
M.default_provider = M.providers[1]

function M.load_candidates(word, opts, complete_fn)
	local popup = require('plenary.popup')
	local row = math.floor((vim.o.lines - 5) / 2)
	local width = math.floor(vim.o.columns / 2)
	local col = math.floor((vim.o.columns - width) / 2)
	local provider_name = opts.provider or M.default_provider
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
	vim.defer_fn(
		vim.schedule_wrap(function()
			local provider = M.get_provider(provider_name)
			if not provider then
				vim.notify(
					'Unable to load provider: ' .. opts.provider,
					vim.log.levels.ERROR
				)
				return
			end
			local candidates, view, word_found = provider.query(word)
			if not candidates then
				vim.notify('Unable to fetch results', vim.log.levels.ERROR)
				return
			end

			if not pcall(vim.api.nvim_win_close, prompt_win, true) then
				vim.notify('Unable to close window: ' .. string(prompt_win))
			end
			complete_fn(candidates, view, word_found, opts)
		end),
		10
	)
end

-- Import and return provider by name.
---@private
---@param name string
---@return table?
function M.get_provider(name)
	local _, p =
		pcall(require, 'telescope._extensions.thesaurus.provider.' .. name)

	if not p then
		vim.notify('Invalid provider: ' .. name, vim.log.levels.ERROR)
		return nil
	end
	return p
end

-- Make new picker and fetch suggestions.
---@private
---@param candidates table
---@param preview_content table
---@param word_found boolean
---@param opts table
function M.new_picker(candidates, preview_content, word_found, opts)
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local finders = require('telescope.finders')
	local telescope_config = require('telescope.config')

	local previewer = nil
	local width = 0.27
	local height = 0.55
	if word_found then
		previewer = M._preview(preview_content)
		width = 0.5
	end

	require('telescope.pickers')
		.new(opts, {
			layout_strategy = 'cursor',
			layout_config = { width = width, height = height },
			prompt_title = '',
			results_title = '',
			finder = finders.new_table({ results = candidates }),
			sorter = telescope_config.values.generic_sorter(opts),
			previewer = previewer,
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					if selection == nil then
						require('telescope.utils').__warn_no_selection('builtin.thesaurus')
						return
					end

					actions.close(prompt_bufnr)
					if not word_found then
						opts.word = selection[1]
						M.query(opts)
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
function M._preview(text)
	return require('telescope.previewers').new_buffer_previewer({
		keep_last_buf = true,
		define_preview = function(self, _, _)
			local bufnr = self.state.bufnr
			vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, text)
			local winid = self.state.winid
			vim.api.nvim_set_option_value('number', false, { win = winid })
			vim.api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })
		end,
	})
end

--- Lookup word under cursor.
---@param opts table
function M.lookup(opts)
	local cursor_word = vim.fn.expand('<cword>')
	M.load_candidates(cursor_word, opts, M.new_picker)
end

--- Query word manually.
---@param opts table<string, string>
function M.query(opts)
	if not opts.word then
		vim.notify('You must specify a word', vim.log.levels.ERROR)
	end
	M.load_candidates(opts.word, opts, M.new_picker)
end

return M
