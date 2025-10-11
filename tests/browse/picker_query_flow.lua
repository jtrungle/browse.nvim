
local helpers = require("helpers")
helpers.setup_mocks()

describe("Picker Query Flow", function()
    before_each(function()
        helpers.mock_telescope()
        package.loaded["browse.bookmarks"] = nil
        package.loaded["browse.bookmark_manager"] = nil
        package.loaded["browse.config"] = nil
    end)

    local function setup_test(persist_query)
        local browse_bookmarks = require("browse.bookmarks")
        local config = require("browse.config")
        config.opts.persist_grouped_bookmarks_query = persist_query

        local bookmarks = {
            group1 = {
                name = "Group 1",
                bookmark1 = "https://bookmark1.com",
                nested_group = {
                    name = "Nested Group",
                    bookmark2 = "https://bookmark2.com",
                },
            },
            bookmark3 = "https://bookmark3.com",
        }

        return browse_bookmarks, bookmarks
    end

    it("should persist query when persist_grouped_bookmarks_query is true", function()
        local browse_bookmarks, bookmarks = setup_test(true)

        -- 1. Open bookmarks and search
        browse_bookmarks.search_bookmarks({ bookmarks = bookmarks })
        helpers.set_picker_input("group")

        -- 2. Select group1
        helpers.select_entry_by_value("group1")

        -- 3. Check if query is persisted
        assert.are.equal("group", helpers.get_picker_input())

        -- 4. Select nested_group
        helpers.select_entry_by_value("nested_group")

        -- 5. Check if query is still persisted
        assert.are.equal("group", helpers.get_picker_input())

        -- 6. Go back
        helpers.select_entry_by_value("back")

        -- 7. Check if query is still persisted
        assert.are.equal("group", helpers.get_picker_input())

        -- 8. Go back again
        helpers.select_entry_by_value("back")

        -- 9. Check if query is still persisted
        assert.are.equal("group", helpers.get_picker_input())
    end)

    it("should clear query when persist_grouped_bookmarks_query is false", function()
        local browse_bookmarks, bookmarks = setup_test(false)

        -- 1. Open bookmarks and search
        browse_bookmarks.search_bookmarks({ bookmarks = bookmarks })
        helpers.set_picker_input("group")

        -- 2. Select group1
        helpers.select_entry_by_value("group1")

        -- 3. Check if query is cleared
        assert.are.equal("", helpers.get_picker_input())

        -- 4. Search again and select nested_group
        helpers.set_picker_input("nested")
        helpers.select_entry_by_value("nested_group")

        -- 5. Check if query is cleared
        assert.are.equal("", helpers.get_picker_input())

        -- 6. Go back
        helpers.select_entry_by_value("back")

        -- 7. Check if query is cleared
        assert.are.equal("", helpers.get_picker_input())

        -- 8. Go back again
        helpers.select_entry_by_value("back")

        -- 9. Check if query is cleared
        assert.are.equal("", helpers.get_picker_input())
    end)
end)
