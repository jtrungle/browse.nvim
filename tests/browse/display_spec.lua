local helpers = require("helpers")
helpers.setup_mocks()

describe("Display Formatting", function()
    before_each(function()
        helpers.mock_telescope()
        package.loaded["browse.bookmarks"] = nil
        package.loaded["browse.config"] = nil
    end)

    it("should display the count for grouped bookmarks", function()
        -- 1. Setup
        local bookmarks_module = require("browse.bookmarks")
        local captured_entry_maker

        local pickers = require("telescope.pickers")
        local original_pickers_new = pickers.new
        pickers.new = function(_, picker_opts)
            local finder = picker_opts.finder
            captured_entry_maker = finder.entry_maker
            return { find = function() end }
        end

        -- 2. Trigger a bookmark search to capture the entry_maker
        bookmarks_module.search_bookmarks({
            bookmarks = {
                my_group = {
                    name = "My Test Group",
                    item1 = "https://a.com",
                    item2 = "https://b.com",
                },
            },
        })
        pickers.new = original_pickers_new -- Restore

        -- 3. Create a sample entry for the group
        local group_entry = { "my_group", {
            name = "My Test Group",
            item1 = "https://a.com",
            item2 = "https://b.com",
        } }

        -- 4. Call the captured entry_maker and assert the display string
        assert.is_function(captured_entry_maker, "Failed to capture entry_maker")
        local result = captured_entry_maker(group_entry)

        -- The display should be something like: "my_group   -> My Test Group (2)"
        assert.is_string(result.display)
        assert(string.match(result.display, "%(2%)"), "Display string should contain the count '(2)'")
    end)
end)
