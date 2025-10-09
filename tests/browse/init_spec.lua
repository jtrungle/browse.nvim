local helpers = require("helpers")
helpers.setup_mocks()

local config = require("browse.config")

describe("browse.init", function()
    before_each(function()
        helpers.mock_telescope()
    end)

    it("should create default commands when configured", function()
        local commands_created = {}
        vim.api.nvim_create_user_command = function(name, rhs, opts)
            commands_created[name] = { rhs = rhs, opts = opts }
        end

        -- Re-require init.lua after mocking to ensure it uses the mock
        package.loaded["browse.init"] = nil
        local browse = require("browse.init")

        -- Setup with create_commands = true
        browse.setup({ create_commands = true })

        assert.is_not_nil(commands_created["Browse"])
        assert.is_not_nil(commands_created["BrowseManualBookmarks"])
        assert.is_not_nil(commands_created["BrowseBrowserBookmarks"])
        assert.is_not_nil(commands_created["BrowseSearch"])
        assert.is_not_nil(commands_created["DevdocsSearch"])
        assert.is_not_nil(commands_created["MdnSearch"])
    end)

    it("should NOT create commands when disabled", function()
        local commands_created = {}
        vim.api.nvim_create_user_command = function(name, rhs, opts)
            commands_created[name] = { rhs = rhs, opts = opts }
        end

        -- Re-require init.lua after mocking
        package.loaded["browse.init"] = nil
        local browse = require("browse.init")

        -- Setup with create_commands = false
        browse.setup({ create_commands = false })

        assert.is_true(vim.tbl_isempty(commands_created))
    end)
end)
