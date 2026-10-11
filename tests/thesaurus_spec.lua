-- thesaurus: providers fed with tests/fixtures, the picker flow in a child
-- Neovim with curl stubbed, config validation, commands and health.

local H = { eq = MiniTest.expect.equality }

-- Fails unless `str` matches the Lua pattern `pat`.
---@param str string
---@param pat string
function H.match(str, pat)
	if not str:find(pat) then
		error(('%q does not match %q'):format(str, pat), 0)
	end
end

-- Plugin root, from this file's path.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
local opt = vim.fn.stdpath('data') .. '/site/pack/core/opt/'

---@param name string fixture file name without .json
---@return string
local function fixture(name)
	local path = root .. '/tests/fixtures/provider/' .. name .. '.json'
	return table.concat(vim.fn.readfile(path), '\n')
end

local child = MiniTest.new_child_neovim()

-- Restarts the child with the plugin, telescope and snacks on
-- 'runtimepath' and `g` as vim.g.thesaurus. Config is read on first use,
-- so setting it after startup is enough. `without` leaves a picker
-- plugin off 'runtimepath'.
---@param g? table
---@param without? 'snacks'|'telescope'
local function start(g, without)
	local paths = { root, opt .. 'plenary.nvim' }
	for _, name in ipairs({ 'telescope', 'snacks' }) do
		if name ~= without then
			table.insert(paths, opt .. name .. '.nvim')
		end
	end
	child.restart({
		'--cmd',
		'set rtp^=' .. table.concat(paths, ','),
		'--cmd',
		'set lines=40 columns=160',
	})
	-- Record notifications instead of showing them.
	child.lua(
		[[
		vim.g.thesaurus = ...
		_G.notes = {}
		vim.notify = function(msg, level)
			table.insert(_G.notes, { msg = msg, level = level })
		end
		-- Picker prompt filetypes, by picker name.
		_G.prompts = { TelescopePrompt = 'telescope', snacks_picker_input = 'snacks' }
		_G.open_picker = function()
			for _, w in ipairs(vim.api.nvim_list_wins()) do
				local name = _G.prompts[vim.bo[vim.api.nvim_win_get_buf(w)].filetype]
				if name then
					return name
				end
			end
		end
	]],
		{ g }
	)
end

-- Replaces vim.system in the child. Each call takes the next response
-- and records the command in _G.calls.
---@param responses { code?: integer, stdout?: string, stderr?: string }[]
local function stub_curl(responses)
	child.lua(
		[[
		_G.calls = {}
		local responses = ...
		vim.system = function(cmd, _, on_exit)
			table.insert(_G.calls, cmd)
			local res = table.remove(responses, 1)
			vim.schedule(function()
				on_exit({
					code = res.code or 0,
					signal = 0,
					stdout = res.stdout or '',
					stderr = res.stderr or '',
				})
			end)
			return {}
		end
	]],
		{ responses }
	)
end

-- curl output for `body` with HTTP `status`, as --write-out formats it.
---@param body string
---@param status integer
local function http(body, status)
	return { stdout = body .. '\n' .. status }
end

-- Waits until a notification arrives or a picker opens.
local function settle()
	child.lua([[
		vim.wait(3000, function()
			return #_G.notes > 0 or _G.open_picker() ~= nil
		end, 10)
		vim.wait(50)
	]])
end

-- Waits until no picker is open.
local function closed()
	child.lua([[vim.wait(1000, function() return _G.open_picker() == nil end)]])
	child.lua([[vim.wait(50)]])
end

---@return 'telescope'|'snacks'|nil name of the open picker
local function open_picker()
	return child.lua_get('_G.open_picker()')
end

---@return boolean
local function picker_open()
	return child.lua_get('_G.open_picker() ~= nil')
end

-- Telescope draws its titles in border windows, so read the screen.
---@return string text shown on screen, rows joined
local function titles()
	local rows = {}
	for _, row in ipairs(child.get_screenshot().text) do
		table.insert(rows, table.concat(row))
	end
	return table.concat(rows, '\n')
end

---@return { msg: string, level: integer }[]
local function notes()
	return child.lua_get('_G.notes')
end

---@return string[] urls requested, the last curl argument
local function urls()
	return child.lua_get([[vim.tbl_map(function(cmd)
		return cmd[#cmd]
	end, _G.calls)]])
end

-- Buffer with `line`, cursor at byte column `col`.
---@param line string
---@param col integer 0-based
local function set_line(line, col)
	child.api.nvim_buf_set_lines(0, 0, -1, false, { line })
	child.api.nvim_win_set_cursor(0, { 1, col })
end

local T = MiniTest.new_set({
	hooks = {
		post_once = child.stop,
	},
})

-- Providers -----------------------------------------------------------

T['provider'] = MiniTest.new_set()

T['provider']['dictionaryapi parses synonyms and antonyms'] = function()
	local p = require('thesaurus.provider.dictionaryapi')
	local words, preview =
		p.parse_result(vim.json.decode(fixture('dictionaryapi')))
	H.eq(words[1], 'regional')
	H.eq(vim.tbl_contains(words, 'native'), true)
	H.eq(preview[1], '# local (adjective)')
	H.eq(
		vim.tbl_contains(
			preview,
			'  antonyms: nonindigenous; nonnative; imported; introduced; transplanted; alien; exotic; foreign; strange; expatriate; immigrant'
		),
		true
	)
end

T['provider']['freedictionaryapi parses words and definitions'] = function()
	local p = require('thesaurus.provider.freedictionaryapi')
	local words, preview =
		p.parse_result(vim.json.decode(fixture('freedictionaryapi')))
	H.eq(words[1], 'local')
	H.eq(preview[1], '# local (noun)')
	H.eq(#preview > 5, true)
end

T['provider']['datamuse parses words'] = function()
	local p = require('thesaurus.provider.datamuse')
	local words, preview = p.parse_result(vim.json.decode(fixture('datamuse')))
	H.eq(words[1], 'localized')
	H.eq(#words, #vim.json.decode(fixture('datamuse')))
	H.eq(preview, {})
end

-- Pickers ------------------------------------------------------------

-- The same flows for every picker.
T['picker'] = MiniTest.new_set({
	parametrize = { { 'telescope' }, { 'snacks' } },
})

T['picker']['picks a synonym that replaces the word after the cursor'] = function(
	picker
)
	start({ api_key = 'k', picker = picker })
	stub_curl({ http(fixture('dictionaryapi'), 200) })
	-- Cursor on the space before "local", like <cword>.
	set_line('a local, word', 1)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(open_picker(), picker)
	H.eq(urls(), {
		'https://www.dictionaryapi.com/api/v3/references/thesaurus/json/local?key=k',
	})
	child.type_keys('<CR>')
	closed()
	H.eq(child.api.nvim_get_current_line(), 'a regional, word')
	H.eq(notes(), {})
end

T['picker']['suggestions re-query multi-word picks encoded'] = function(picker)
	start({ api_key = 'k', picker = picker })
	stub_curl({
		http(fixture('dictionaryapi-error'), 200),
		http(fixture('dictionaryapi'), 200),
	})
	set_line('lcal', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(open_picker(), picker)
	child.type_keys('close call')
	child.lua([[vim.wait(200)]])
	child.type_keys('<CR>')
	child.lua([[vim.wait(1000, function() return #_G.calls == 2 end)]])
	H.eq(
		urls()[2],
		'https://www.dictionaryapi.com/api/v3/references/thesaurus/json/close%20call?key=k'
	)
	settle()
	-- The synonym still replaces the original word.
	child.type_keys('<CR>')
	closed()
	H.eq(child.api.nvim_get_current_line(), 'regional')
end

T['picker']['query picks yank the word'] = function(picker)
	start({ provider = 'datamuse', picker = picker })
	stub_curl({ http(fixture('datamuse'), 200) })
	set_line('unchanged', 0)
	child.cmd('Thesaurus query local')
	settle()
	H.eq(open_picker(), picker)
	child.type_keys('<CR>')
	child.lua([[vim.wait(1000, function() return #_G.notes > 0 end)]])
	H.eq(child.fn.getreg('"'), 'localized')
	H.eq(child.api.nvim_get_current_line(), 'unchanged')
end

T['picker']['missing plugin is reported and sends no request'] = function(
	picker
)
	start({ provider = 'datamuse', picker = picker }, picker)
	stub_curl({})
	set_line('local', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(urls(), {})
	H.eq(notes(), {
		{
			msg = ('%s.nvim is required for picker = "%s"'):format(picker, picker),
			level = vim.log.levels.ERROR,
		},
	})
end

-- Lookups -------------------------------------------------------------

T['lookup'] = MiniTest.new_set()

T['lookup']['auto picker prefers snacks, else telescope'] = function()
	start({ provider = 'datamuse' })
	stub_curl({ http(fixture('datamuse'), 200) })
	set_line('local', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(open_picker(), 'snacks')

	start({ provider = 'datamuse' }, 'snacks')
	stub_curl({ http(fixture('datamuse'), 200) })
	set_line('local', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(open_picker(), 'telescope')
end

T['lookup']['returns at once and reports an unreachable host'] = function()
	start({ provider = 'datamuse' })
	set_line('local', 0)
	-- Real curl. Nothing listens on the discard port.
	local elapsed = child.lua([[
		require('thesaurus.provider.datamuse').url = 'http://127.0.0.1:9/words'
		local start = vim.uv.hrtime()
		require('thesaurus').lookup()
		return (vim.uv.hrtime() - start) / 1e6
	]])
	H.eq(elapsed < 500, true)
	settle()
	local got = notes()
	H.eq(#got, 1)
	H.eq(got[1].level, vim.log.levels.ERROR)
	H.match(got[1].msg, '^Unable to fetch from 127%.0%.0%.1:9')
	H.eq(picker_open(), false)
end

T['picker']['unknown word says so in the picker title'] = function(picker)
	start({ provider = 'datamuse', picker = picker })
	stub_curl({ http(fixture('datamuse-error'), 200) })
	set_line('qwzx', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(open_picker(), picker)
	H.match(titles(), 'No results for "qwzx"')
	H.eq(notes(), {})
end

T['picker']['404 from freedictionaryapi says so in the picker title'] = function(
	picker
)
	start({ provider = 'freedictionaryapi', picker = picker })
	stub_curl({ http(fixture('freedictionaryapi-error'), 404) })
	set_line('lcal', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(open_picker(), picker)
	H.match(titles(), 'No results for "lcal"')
	H.eq(notes(), {})
end

T['picker']['suggestions say the word was not found'] = function(picker)
	start({ api_key = 'k', picker = picker })
	stub_curl({ http(fixture('dictionaryapi-error'), 200) })
	set_line('lcal', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(open_picker(), picker)
	H.match(titles(), '"lcal" not found, did you mean%?')
end

T['picker']['found words have no not-found title'] = function(picker)
	start({ provider = 'datamuse', picker = picker })
	stub_curl({ http(fixture('datamuse'), 200) })
	set_line('local', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(open_picker(), picker)
	H.eq(titles():find('not found', 1, true), nil)
	H.eq(titles():find('No results', 1, true), nil)
end

T['lookup']['non-2xx responses are reported'] = function()
	start({ api_key = 'bad' })
	stub_curl({ http('<html>Unauthorized</html>', 401) })
	set_line('local', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(picker_open(), false)
	-- The loading popup is closed too.
	H.eq(child.lua_get([[#vim.api.nvim_list_wins()]]), 1)
	H.eq(notes(), {
		{
			msg = 'www.dictionaryapi.com returned HTTP 401',
			level = vim.log.levels.ERROR,
		},
	})
end

T['lookup']['unexpected JSON is reported and closes the popup'] = function()
	start({ provider = 'freedictionaryapi' })
	-- datamuse's shape, not freedictionaryapi's.
	stub_curl({ http(fixture('datamuse'), 200) })
	set_line('local', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(picker_open(), false)
	H.eq(child.lua_get([[#vim.api.nvim_list_wins()]]), 1)
	H.eq(#notes(), 1)
	H.match(notes()[1].msg, '^Unexpected response from dictionaryapi%.dev: ')
end

T['lookup']['missing dictionaryapi key sends no request'] = function()
	start()
	child.lua([[vim.env.DICTIONARY_API_KEY = nil]])
	stub_curl({})
	set_line('local', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	H.eq(picker_open(), false)
	H.eq(urls(), {})
	H.eq(#notes(), 1)
	H.match(notes()[1].msg, 'dictionaryapi%.com key')
end

T['lookup']['reuses one telescope preview buffer'] = function()
	start({ api_key = 'k', picker = 'telescope' })
	stub_curl({ http(fixture('dictionaryapi'), 200) })
	set_line('local', 0)
	local before = #child.api.nvim_list_bufs()
	child.lua([[require('thesaurus').lookup()]])
	settle()
	-- Move through a few entries, then close.
	child.type_keys('<C-n>', '<C-n>', '<C-n>')
	child.lua([[vim.wait(200)]])
	child.lua(
		[[require('telescope.actions').close(vim.api.nvim_get_current_buf())]]
	)
	child.lua([[vim.wait(200)]])
	H.eq(#child.api.nvim_list_bufs(), before)
end

-- Query ---------------------------------------------------------------

T['query'] = MiniTest.new_set()

T['query'][':Thesaurus query encodes multi-word queries'] = function()
	start({ provider = 'datamuse' })
	stub_curl({ http(fixture('datamuse'), 200) })
	child.cmd('Thesaurus query close call')
	settle()
	H.eq(urls(), { 'https://api.datamuse.com/words?max=100&ml=close%20call' })
	H.eq(picker_open(), true)
end

T['query'][':Telescope thesaurus opens telescope with its setup options'] = function()
	-- snacks is available too, so 'auto' would pick it.
	start()
	child.lua([[require('telescope').setup({
		extensions = { thesaurus = { provider = 'freedictionaryapi' } },
	})]])
	stub_curl({ http(fixture('freedictionaryapi'), 200) })
	child.cmd('Telescope thesaurus query word=local')
	settle()
	H.eq(urls(), { 'https://api.dictionaryapi.dev/api/v2/entries/en/local' })
	H.eq(open_picker(), 'telescope')
end

T['query']['without a word is an error'] = function()
	start()
	child.cmd('Thesaurus query')
	H.eq(notes(), {
		{ msg = 'You must specify a word', level = vim.log.levels.ERROR },
	})
end

-- Plugin entry, config and health -------------------------------------

T['plugin'] = MiniTest.new_set()

T['plugin']['defines the command and map without loading modules'] = function()
	start()
	H.eq(child.fn.exists(':Thesaurus'), 2)
	H.eq(child.fn.maparg('<Plug>(ThesaurusLookup)', 'n') ~= '', true)
	H.eq(child.lua_get([[package.loaded['thesaurus'] == nil]]), true)
	H.eq(child.fn.getcompletion('Thesaurus ', 'cmdline'), { 'lookup', 'query' })
	child.cmd('Thesaurus nope')
	H.eq(notes(), {
		{
			msg = 'thesaurus: unknown subcommand nope',
			level = vim.log.levels.ERROR,
		},
	})
end

T['plugin']['invalid provider is reported once and ignored'] = function()
	start({ provider = 'nope' })
	child.lua([[vim.env.DICTIONARY_API_KEY = 'k']])
	stub_curl({ http(fixture('dictionaryapi'), 200) })
	set_line('local', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	local got = notes()
	H.eq(#got, 1)
	H.match(got[1].msg, '^thesaurus: vim%.g%.thesaurus%.provider: ')
	H.match(got[1].msg, 'one of dictionaryapi, datamuse, freedictionaryapi')
	-- The default provider is used instead.
	H.eq(urls(), {
		'https://www.dictionaryapi.com/api/v3/references/thesaurus/json/local?key=k',
	})
	H.eq(picker_open(), true)
end

T['plugin']['invalid picker is reported once and ignored'] = function()
	start({ picker = 'fzf' })
	child.lua([[vim.env.DICTIONARY_API_KEY = 'k']])
	stub_curl({ http(fixture('dictionaryapi'), 200) })
	set_line('local', 0)
	child.lua([[require('thesaurus').lookup()]])
	settle()
	local got = notes()
	H.eq(#got, 1)
	H.match(got[1].msg, '^thesaurus: vim%.g%.thesaurus%.picker: ')
	H.match(got[1].msg, 'one of auto, snacks, telescope')
	-- The default picker is used instead.
	H.eq(open_picker(), 'snacks')
end

T['plugin']['checkhealth reports config and key problems'] = function()
	start({ provider = 'dictionaryapi', mappings = {} })
	child.lua([[vim.env.DICTIONARY_API_KEY = nil]])
	child.cmd('checkhealth thesaurus')
	local text = table.concat(child.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
	H.match(text, 'curl is installed')
	H.match(text, 'vim%.g%.thesaurus%.mappings is not an option')
	H.match(text, 'dictionaryapi%.com key is missing')
	H.match(text, 'Picker: snacks %(picker = "auto"%)')
end

return T
