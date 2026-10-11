-- Telescope-thesaurus: telescope.nvim picker
-- https://github.com/rafi/telescope-thesaurus.nvim

---@type thesaurus.Picker
local M = { name = 'telescope' }

function M.available()
	return (pcall(require, 'telescope'))
end

-- Previewer showing the same markdown lines for every entry.
---@param text string[]
---@return table
local function previewer(text)
	return require('telescope.previewers').new_buffer_previewer({
		-- Reuse one buffer for every entry.
		get_buffer_by_name = function()
			return 'thesaurus-preview'
		end,
		define_preview = function(self)
			local winid = self.state.winid
			vim.api.nvim_set_option_value('number', false, { win = winid })
			vim.api.nvim_set_option_value('wrap', true, { win = winid })
			-- Telescope sets bufname when it reuses the filled buffer.
			if self.state.bufname then
				return
			end
			local bufnr = self.state.bufnr
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
			vim.api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })
		end,
	})
end

-- True when telescope.setup() changed the layout. It doesn't record what
-- the user set, so compare with telescope's own defaults.
---@return boolean
local function user_layout()
	local values = require('telescope.config').values
	if values.layout_strategy ~= 'horizontal' then
		return true
	end
	local layout = values.layout_config or {}
	local h, c = layout.horizontal or {}, layout.cursor or {}
	return h.width ~= 0.8 or h.height ~= 0.9 or c.width ~= 0.8 or c.height ~= 0.9
end

---@param result thesaurus.Result
---@param pick fun(word?: string)
---@param opts table telescope picker options
function M.open(result, pick, opts)
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')

	local preview = nil
	local width = 0.27
	if #result.preview > 0 then
		preview = previewer(result.preview)
		width = 0.5
	end
	-- Room for the not-found message in the prompt title.
	if result.title then
		width = math.max(width, 0.35)
	end

	-- A compact popup at the cursor, unless the user chose a layout in
	-- telescope.setup() or passed one in the options.
	local layout = {}
	if not (opts.layout_strategy or opts.layout_config or user_layout()) then
		layout = {
			layout_strategy = 'cursor',
			layout_config = {
				prompt_position = 'top',
				width = width,
				height = 0.55,
			},
		}
	end

	require('telescope.pickers')
		.new(
			opts,
			vim.tbl_extend('error', layout, {
				prompt_title = result.title or '',
				results_title = '',
				finder = require('telescope.finders').new_table({
					results = result.candidates,
				}),
				sorter = require('telescope.config').values.generic_sorter(opts),
				previewer = preview,
				attach_mappings = function()
					actions.select_default:replace(function(prompt_bufnr)
						local selection = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						pick(selection and selection[1])
					end)
					return true
				end,
			})
		)
		:find()
end

return M
