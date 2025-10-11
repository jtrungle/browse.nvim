local helpers = require("helpers")
helpers.setup_mocks()

local config = require("browse.config")

describe("browse.init", function()
    before_each(function()
        helpers.mock_telescope()
    end)

    it("should create the unified Browse command when configured", function()
        local command_created = nil
        vim.api.nvim_create_user_command = function(name, rhs, opts)
            if name == "Browse" then
                command_created = { name = name, rhs = rhs, opts = opts }
            end
        end

        -- Re-require init.lua after mocking to ensure it uses the mock
        package.loaded["browse.init"] = nil
        local browse = require("browse.init")

        -- Setup with create_commands = true
        browse.setup({ create_commands = true })

        assert.is_not_nil(command_created)
        assert.are.equal("Browse", command_created.name)
        assert.are.equal("*", command_created.opts.nargs)
        assert.are.equal("customlist,v:lua.require'browse.utils'.command_completer", command_created.opts.complete)
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
