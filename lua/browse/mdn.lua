local utils = require("browse.utils")

local M = {}

M.search = utils.format_search(
    "https://developer.mozilla.org/en-US/search?q=%s",
    { prompt = "MDN search:" }
)

M.search_with_filetype = utils.format_search(
    "https://developer.mozilla.org/en-US/search?q=" .. vim.bo.filetype .. " %s",
    { prompt = "MDN filetype search:" }
)

return M
