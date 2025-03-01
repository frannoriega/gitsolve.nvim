local M = {}

function M.setup()
    -- Register the user command
    vim.api.nvim_create_user_command('GitSolve', function()
        require('gitsolve.telescope').open_gitsolve()
    end, {})
end

return M
