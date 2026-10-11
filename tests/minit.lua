#!/usr/bin/env -S nvim -l
-- Test bootstrap: point every stdpath at .tests/, install mini.test,
-- plenary.nvim, telescope.nvim and snacks.nvim there with vim.pack, put
-- this plugin on 'runtimepath', run tests/*_spec.lua.
--
-- Usage: nvim -l tests/minit.lua [spec files...]

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
for _, name in ipairs({ 'config', 'data', 'state', 'cache' }) do
	vim.env[('XDG_%s_HOME'):format(name:upper())] = root .. '/.tests/' .. name
end
vim.fn.mkdir(vim.fn.stdpath('config'), 'p')
-- 'packlockfile' and 'packpath' were computed from the real dirs at startup.
if vim.fn.exists('+packlockfile') == 1 then
	vim.o.packlockfile = vim.fn.stdpath('config') .. '/nvim-pack-lock.json'
end
vim.opt.packpath:prepend(vim.fn.stdpath('data') .. '/site')
vim.opt.runtimepath:prepend(root)
vim.pack.add({
	'https://github.com/nvim-mini/mini.test',
	'https://github.com/nvim-lua/plenary.nvim',
	'https://github.com/nvim-telescope/telescope.nvim',
	'https://github.com/folke/snacks.nvim',
}, { confirm = false })
require('mini.test').setup({
	collect = {
		find_files = function()
			return #_G.arg > 0 and _G.arg
				or vim.fn.globpath(root .. '/tests', '*_spec.lua', true, true)
		end,
	},
})
MiniTest.run()
