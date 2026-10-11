-- Telescope-thesaurus: snacks.nvim picker
-- https://github.com/rafi/telescope-thesaurus.nvim

---@type thesaurus.Picker
local M = { name = 'snacks' }

function M.available()
	local ok, snacks = pcall(require, 'snacks')
	return ok and snacks.picker ~= nil
end

-- True when the user set a snacks layout, for all pickers or for this
-- source. Snacks' own default is a function preset.
---@return boolean
local function user_layout()
	local cfg = require('snacks').config.picker or {}
	if cfg.sources and cfg.sources.thesaurus and cfg.sources.thesaurus.layout then
		return true
	end
	local layout = cfg.layout
	if type(layout) == 'string' then
		return true
	end
	return type(layout) == 'table'
		and (layout.layout ~= nil or type(layout.preset) == 'string')
end

---@param result thesaurus.Result
---@param pick fun(word?: string)
---@param opts table snacks picker options, merged over ours
function M.open(result, pick, opts)
	local has_preview = #result.preview > 0
	-- Every entry previews the same markdown lines.
	local preview = has_preview
			and {
				text = table.concat(result.preview, '\n'),
				ft = 'markdown',
				loc = false,
			}
		or nil
	local items = {}
	for i, word in ipairs(result.candidates) do
		items[i] = { idx = i, text = word, preview = preview }
	end

	require('snacks').picker.pick(vim.tbl_deep_extend('force', {
		source = 'thesaurus',
		title = result.title or 'Thesaurus',
		items = items,
		-- Without it snacks closes the picker and notifies on an empty list.
		show_empty = true,
		format = 'text',
		preview = has_preview and 'preview' or 'none',
		-- The preview is prose, so no line numbers.
		win = { preview = { wo = { number = false } } },
		-- Candidates left (30%), preview right (70%), unless the user set a
		-- layout.
		layout = not user_layout() and (has_preview and {
			layout = {
				box = 'horizontal',
				width = 0.6,
				min_width = 80,
				height = 0.6,
				{
					box = 'vertical',
					border = true,
					title = '{title} {live} {flags}',
					width = 0.3,
					{ win = 'input', height = 1, border = 'bottom' },
					{ win = 'list', border = 'none' },
				},
				{ win = 'preview', title = '{preview}', border = true, width = 0.7 },
			},
		} or { preset = 'select' }) or nil,
		confirm = function(picker, item)
			picker:close()
			-- Run after the picker window is gone, so a replace or a new
			-- lookup starts from the original window.
			vim.schedule(function()
				pick(item and item.text)
			end)
		end,
	}, opts))
end

return M
