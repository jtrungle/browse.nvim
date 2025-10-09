local M = {}

local browser_bookmarks = require("browse.browser_bookmarks")
local file_bookmarks = require("browse.file_bookmarks")
local config = require("browse.config")

-- Bookmark source types
M.SOURCE_TYPES = {
    CONFIG = "config",        -- From Lua config
    FILE = "file",           -- From external file
    BROWSER = "browser"      -- From browser import
}

-- Merge multiple bookmark tables
function M.merge_bookmarks(...)
    local merged = {}
    local bookmark_tables = {...}
    
    for _, bookmarks in ipairs(bookmark_tables) do
        if type(bookmarks) == "table" then
            for key, value in pairs(bookmarks) do
                if type(key) == "number" then
                    -- Array-style entry
                    table.insert(merged, value)
                elseif type(key) == "string" then
                    if type(value) == "string" then
                        -- Direct key-value mapping
                        merged[key] = value
                    elseif type(value) == "table" then
                        -- Grouped bookmarks
                        if merged[key] then
                            -- Merge with existing group
                            if type(merged[key]) == "table" then
                                for sub_key, sub_value in pairs(value) do
                                    merged[key][sub_key] = sub_value
                                end
                            else
                                -- Convert to group
                                local old_value = merged[key]
                                merged[key] = vim.deepcopy(value)
                                merged[key]["_original"] = old_value
                            end
                        else
                            merged[key] = vim.deepcopy(value)
                        end
                    end
                end
            end
        end
    end
    
    return merged
end

-- Deduplicate bookmarks based on URL
function M.deduplicate_bookmarks(bookmarks)
    local seen_urls = {}
    local unique_bookmarks = {}
    
    local function process_entry(key, value, container)
        if type(value) == "string" and value:match("^https?://") then
            if not seen_urls[value] then
                seen_urls[value] = true
                container[key] = value
            end
        elseif type(value) == "table" then
            local unique_group = {}
            for sub_key, sub_value in pairs(value) do
                process_entry(sub_key, sub_value, unique_group)
            end
            if not vim.tbl_isempty(unique_group) then
                container[key] = unique_group
            end
        else
            container[key] = value
        end
    end
    
    for key, value in pairs(bookmarks) do
        process_entry(key, value, unique_bookmarks)
    end
    
    return unique_bookmarks
end

-- Validate bookmark structure and URLs
function M.validate_bookmarks(bookmarks)
    local errors = {}
    
    if type(bookmarks) ~= "table" then
        table.insert(errors, "Bookmarks must be a table")
        return false, errors
    end
    
    local function validate_url(url, path)
        if type(url) ~= "string" then
            table.insert(errors, "URL at " .. path .. " must be a string")
            return false
        end
        
        if not url:match("^https?://") and not url:match("%%s") then
            table.insert(errors, "Invalid URL at " .. path .. ": " .. url)
            return false
        end
        
        return true
    end
    
    local function validate_entry(key, value, path)
        local current_path = path and (path .. "." .. tostring(key)) or tostring(key)
        
        if type(value) == "string" then
            return validate_url(value, current_path)
        elseif type(value) == "table" then
            for sub_key, sub_value in pairs(value) do
                if sub_key ~= "name" and not validate_entry(sub_key, sub_value, current_path) then
                    return false
                end
            end
            return true
        else
            table.insert(errors, "Invalid bookmark type at " .. current_path)
            return false
        end
    end
    
    for key, value in pairs(bookmarks) do
        validate_entry(key, value)
    end
    
    return vim.tbl_isempty(errors), errors
end

-- Normalize bookmark structure
function M.normalize_bookmarks(bookmarks)
    local normalized = {}
    
    for key, value in pairs(bookmarks) do
        if type(key) == "number" then
            -- Convert array entries to named entries
            if type(value) == "string" then
                local domain = value:match("https?://([^/]+)")
                local name = domain and domain:gsub("^www%.", "") or ("bookmark_" .. key)
                normalized[name] = value
            end
        else
            normalized[key] = value
        end
    end
    
    return normalized
end

-- Load bookmarks from manual sources (config and files)
function M.load_manual_bookmarks()
    local opts = config.opts or {}
    local manual_sources = {}

    -- Load from config
    if opts.bookmarks and not vim.tbl_isempty(opts.bookmarks) then
        table.insert(manual_sources, opts.bookmarks)
    end

    -- Load from files
    if opts.bookmark_files then
        for _, file_path in ipairs(opts.bookmark_files) do
            local file_bookmarks_data, error = file_bookmarks.load_from_file(file_path)
            if file_bookmarks_data then
                table.insert(manual_sources, file_bookmarks_data)
            else
                vim.notify("Failed to load bookmarks from " .. file_path .. ": " .. (error or "unknown error"), vim.log.levels.WARN)
            end
        end
    end

    if vim.tbl_isempty(manual_sources) then
        return {}
    end

    local merged = M.merge_bookmarks(unpack(manual_sources))
    if opts.deduplicate_bookmarks ~= false then
        merged = M.deduplicate_bookmarks(merged)
    end
    merged = M.normalize_bookmarks(merged)

    return merged
end

-- Load bookmarks from browser sources
function M.load_browser_bookmarks()
    local opts = config.opts or {}
    if not (opts.browser_bookmarks and opts.browser_bookmarks.enabled) then
        return {}
    end

    local browser_config = opts.browser_bookmarks.browsers or {}
    local browser_bookmarks_data = browser_bookmarks.get_all_browser_bookmarks(browser_config)

    if vim.tbl_isempty(browser_bookmarks_data) then
        return {}
    end

    local group_by_folder = opts.browser_bookmarks.group_by_folder ~= false
    local converted = browser_bookmarks.convert_to_browse_format(browser_bookmarks_data, group_by_folder)

    if opts.deduplicate_bookmarks ~= false then
        converted = M.deduplicate_bookmarks(converted)
    end
    converted = M.normalize_bookmarks(converted)

    return converted
end

-- Caching logic
local manual_bookmark_cache = {}
local browser_bookmark_cache = {}
local manual_cache_timestamp = 0
local browser_cache_timestamp = 0
local CACHE_DURATION = 60 -- seconds

-- Get manual bookmarks (cached)
function M.get_manual_bookmarks(force_refresh)
    local current_time = vim.loop.now() / 1000
    if force_refresh or (current_time - manual_cache_timestamp) > CACHE_DURATION or vim.tbl_isempty(manual_bookmark_cache) then
        manual_bookmark_cache = M.load_manual_bookmarks()
        manual_cache_timestamp = current_time
    end
    return manual_bookmark_cache
end

-- Get browser bookmarks (cached)
function M.get_browser_bookmarks(force_refresh)
    local current_time = vim.loop.now() / 1000
    if force_refresh or (current_time - browser_cache_timestamp) > CACHE_DURATION or vim.tbl_isempty(browser_bookmark_cache) then
        browser_bookmark_cache = M.load_browser_bookmarks()
        browser_cache_timestamp = current_time
    end
    return browser_bookmark_cache
end

-- Clear bookmark cache
function M.clear_cache()
    manual_bookmark_cache = {}
    browser_bookmark_cache = {}
    manual_cache_timestamp = 0
    browser_cache_timestamp = 0
end

-- Add bookmark to file
function M.add_bookmark(name, url, file_path, group)
    file_path = file_path or (vim.fn.stdpath("config") .. "/bookmarks.json")
    
    -- Load existing bookmarks
    local existing_bookmarks = {}
    if vim.fn.filereadable(file_path) == 1 then
        local loaded, error = file_bookmarks.load_from_file(file_path)
        if loaded then
            existing_bookmarks = loaded
        else
            vim.notify("Error loading existing bookmarks: " .. (error or "unknown error"), vim.log.levels.ERROR)
            return false
        end
    end
    
    -- Add new bookmark
    if group then
        if not existing_bookmarks[group] then
            existing_bookmarks[group] = { name = group }
        end
        existing_bookmarks[group][name] = url
    else
        existing_bookmarks[name] = url
    end
    
    -- Save back to file
    local success, error = file_bookmarks.save_to_file(existing_bookmarks, file_path)
    if success then
        M.clear_cache() -- Clear cache to force reload
        vim.notify("Bookmark added successfully", vim.log.levels.INFO)
        return true
    else
        vim.notify("Error saving bookmark: " .. (error or "unknown error"), vim.log.levels.ERROR)
        return false
    end
end

-- Search bookmarks
function M.search_bookmarks(query, bookmarks)
    bookmarks = bookmarks or M.get_bookmarks()
    local results = {}
    
    query = query:lower()
    
    local function search_entry(key, value, path)
        local full_path = path and (path .. " > " .. key) or key
        
        if type(value) == "string" then
            -- Search in key and URL
            if tostring(key):lower():find(query) or value:lower():find(query) then
                table.insert(results, {
                    name = full_path,
                    url = value,
                    match_type = "direct"
                })
            end
        elseif type(value) == "table" then
            for sub_key, sub_value in pairs(value) do
                if sub_key ~= "name" then
                    search_entry(sub_key, sub_value, full_path)
                end
            end
        end
    end
    
    for key, value in pairs(bookmarks) do
        search_entry(key, value)
    end
    
    return results
end

-- Get bookmark statistics
function M.get_stats()
    local bookmarks = M.get_bookmarks()
    local stats = {
        total_bookmarks = 0,
        direct_bookmarks = 0,
        grouped_bookmarks = 0,
        groups = 0,
        unique_domains = {}
    }
    
    local function count_entry(value)
        if type(value) == "string" then
            stats.total_bookmarks = stats.total_bookmarks + 1
            stats.direct_bookmarks = stats.direct_bookmarks + 1
            
            -- Extract domain
            local domain = value:match("https?://([^/]+)")
            if domain then
                stats.unique_domains[domain] = true
            end
        elseif type(value) == "table" then
            stats.groups = stats.groups + 1
            for sub_key, sub_value in pairs(value) do
                if sub_key ~= "name" then
                    if type(sub_value) == "string" then
                        stats.total_bookmarks = stats.total_bookmarks + 1
                        stats.grouped_bookmarks = stats.grouped_bookmarks + 1
                        
                        local domain = sub_value:match("https?://([^/]+)")
                        if domain then
                            stats.unique_domains[domain] = true
                        end
                    end
                end
            end
        end
    end
    
    for _, value in pairs(bookmarks) do
        count_entry(value)
    end
    
    stats.unique_domain_count = vim.tbl_count(stats.unique_domains)
    stats.unique_domains = vim.tbl_keys(stats.unique_domains)
    
    return stats
end

return M
