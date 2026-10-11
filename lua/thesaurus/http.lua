-- Telescope-thesaurus: async HTTP GET with curl
-- https://github.com/rafi/telescope-thesaurus.nvim

local M = {}

-- Seconds before curl gives up.
M.timeout = 10

---@class thesaurus.Response
---@field status? integer HTTP status, nil when curl failed
---@field body? string
---@field data? any decoded JSON body, nil when it isn't JSON
---@field err? string why the request failed, nil on HTTP 2xx

-- Percent-encodes a URL path segment or query value.
---@param str string
---@return string
function M.encode(str)
	return (vim.uri_encode(str, 'rfc3986'))
end

-- Builds `url?k=v&...` with encoded values, keys sorted.
---@param url string
---@param query? table<string, string|integer>
---@return string
function M.url(url, query)
	if not query or vim.tbl_isempty(query) then
		return url
	end
	local keys = vim.tbl_keys(query)
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, key .. '=' .. M.encode(tostring(query[key])))
	end
	return url .. '?' .. table.concat(parts, '&')
end

-- Fetches `url` without blocking. `on_done` runs on the main loop.
---@param url string
---@param on_done fun(res: thesaurus.Response)
function M.get(url, on_done)
	local cmd = {
		'curl',
		'--silent',
		'--show-error',
		'--location',
		'--max-time',
		tostring(M.timeout),
		-- Append the status on its own line.
		'--write-out',
		'\n%{http_code}',
		url,
	}
	local ok, err = pcall(vim.system, cmd, { text = true }, function(out)
		vim.schedule(function()
			on_done(M.parse(url, out))
		end)
	end)
	if not ok then
		vim.schedule(function()
			on_done({ err = 'Unable to run curl: ' .. tostring(err) })
		end)
	end
end

-- Turns curl's output into a response.
---@param url string
---@param out vim.SystemCompleted
---@return thesaurus.Response
function M.parse(url, out)
	local host = url:match('^%a+://([^/?]+)') or url
	if out.code ~= 0 then
		local msg = vim.trim(out.stderr or '')
		return { err = ('Unable to fetch from %s: %s'):format(host, msg) }
	end
	local body, status = (out.stdout or ''):match('^(.*)\n(%d+)$')
	status = tonumber(status)
	if not status then
		return { err = ('Unexpected response from %s'):format(host) }
	end
	local res = { status = status, body = body } ---@type thesaurus.Response
	local decoded, data = pcall(vim.json.decode, body)
	if decoded then
		res.data = data
	end
	if status < 200 or status > 299 then
		res.err = ('%s returned HTTP %d'):format(host, status)
	elseif not decoded then
		res.err = ('Unable to decode response from %s'):format(host)
	end
	return res
end

return M
