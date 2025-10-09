local M = {}

-- get os name
local get_os_name = function()
    local os = vim.loop.os_uname()
    local os_name = os.sysname
    return os_name
end

-- WSL
local is_wsl = function()
    local output = vim.fn.systemlist("uname -r")
    return not not string.find(output[1] or "", "WSL")
end

-- get open cmd
local get_open_cmd = function()
    local os_name = get_os_name()

    local open_cmd = nil
    if os_name == "Windows_NT" or os_name == "Windows" then
        open_cmd = { "cmd", "/c", "start" }
    elseif os_name == "Darwin" then
        open_cmd = { "open" }
    else
        if is_wsl() then
            open_cmd = { "wsl-open" }
        else
            open_cmd = { "xdg-open" }
        end
    end
    return open_cmd
end

local escape_target = function(target)
    local escapes = {
        [" "] = "%20",
        ["<"] = "%3C",
        [">"] = "%3E",
        ["#"] = "%23",
        ["%"] = "%25",
        ["+"] = "%2B",
        ["{"] = "%7B",
        ["}"] = "%7D",
        ["|"] = "%7C",
        ["\\"] = "%5C",
        ["^"] = "%5E",
        ["~"] = "%7E",
        ["["] = "%5B",
        ["]"] = "%5D",
        ["‘"] = "%60",
        [";"] = "%3B",
        ["/"] = "%2F",
        ["?"] = "%3F",
        [":"] = "%3A",
        ["@"] = "%40",
        ["="] = "%3D",
        ["&"] = "%26",
        ["$"] = "%24",
    }

    return target:gsub(".", escapes)
end

-- start the browser job
local open_browser = function(target)
    target = vim.fn.trim(target)
    local open_cmd = vim.fn.extend(get_open_cmd(), { target })

    vim.fn.jobstart(open_cmd, { detach = true })
end

M.default_search = function(input)
    open_browser(input)
end

-- a generic searching function used everywhere
M.search = function(target_fn, opts)
    local prompt = opts and opts.prompt or "Search String:"
    local default = opts and opts.visual_text or ""
    vim.ui.input(
        { prompt = prompt, default = default, kind = "browse" },
        function(input)
            if input == nil or input == "" then
                return
            end

            local escaped_input = escape_target(vim.fn.trim(input))
            M.default_search(target_fn(escaped_input))
        end
    )
end

-- a generic searching closure util
M.callback_search = function(custom_fn, opts)
    return function(visual_text)
        opts.visual_text = visual_text
        M.search(custom_fn, opts)
    end
end

-- a generic searching for a format
M.format_search = function(format, opts)
    return function(visual_text)
        opts.visual_text = visual_text
        M.search(function(input)
            return string.format(format, input)
        end, opts)
    end
end

-- get selected text from visual mode (via a temp register)
M.get_visual_text = function()
    local reg_bak = vim.fn.getreg("v")
    vim.fn.setreg("v", {})
    vim.cmd([[noau normal! "vy\<esc\>]])
    local sel_text = vim.fn.getreg("v")
    vim.fn.setreg("v", reg_bak)
    return string.gsub(sel_text, "\n", "")
end

--Get the domain of a URL
--Example: https://obsidian.md => obsidian.md
---@param url string: URL to which your domain will be extracted
---@return string: Domain from the URL
M.get_domain = function(url)
    return string.match(url, "https?://([^/]+)")
end

function M.get_theme(picker_name)
    local config = require("browse.config")
    local themes = require("telescope.themes")

    local theme_config = config.opts.themes and config.opts.themes[picker_name]

    if not theme_config then
        return {} -- Use default Telescope theme
    end

    local theme_name
    local theme_opts = {}

    if type(theme_config) == "string" then
        theme_name = theme_config
    elseif type(theme_config) == "table" then
        theme_name = theme_config[1]
        theme_opts = theme_config[2] or {}
        if type(theme_name) ~= "string" or type(theme_opts) ~= "table" then
            vim.notify("Browse.nvim: Invalid theme table format for " .. picker_name, vim.log.levels.WARN)
            return {}
        end
    else
        vim.notify("Browse.nvim: Invalid theme config for " .. picker_name, vim.log.levels.WARN)
        return {}
    end

    local theme_func = themes["get_" .. theme_name]
    if type(theme_func) ~= "function" then
        vim.notify("Browse.nvim: Invalid theme name '" .. theme_name .. "' for " .. picker_name, vim.log.levels.WARN)
        return {}
    end

    return theme_func(theme_opts)
end

return M
