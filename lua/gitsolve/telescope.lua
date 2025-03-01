local telescope = require('telescope.builtin')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local utils = require('telescope.utils')

local M = {}

function M.open_gitsolve()
    -- Find files with merge conflicts
    local conflict_files = utils.get_os_command_output({ 'git', 'diff', '--name-only', '--diff-filter=U' })

    if #conflict_files == 0 then
        print("No merge conflicts found.")
        return
    end

    -- Open Telescope picker with conflicting files
    telescope.git_files({
        prompt_title = "Resolve Merge Conflicts",
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                M.resolve_conflict(entry.value)
            end)
            return true
        end,
    })
end

function M.resolve_conflict(file_path)
    -- Read the file content
    local lines = vim.fn.readfile(file_path)

    -- Split the content into local and remote changes
    local local_changes = {}
    local remote_changes = {}
    local in_local = false
    local in_remote = false

    for _, line in ipairs(lines) do
        if line:match('^<<<<<<<') then
            in_local = true
        elseif line:match('^=======') then
            in_local = false
            in_remote = true
        elseif line:match('^>>>>>>>') then
            in_remote = false
        else
            if in_local then
                table.insert(local_changes, line)
            elseif in_remote then
                table.insert(remote_changes, line)
            end
        end
    end

    -- Create a Telescope picker to choose between local and remote changes
    local opts = {
        prompt_title = "Choose Changes for " .. file_path,
        entries = {
            { value = 'local', display = 'Local Changes' },
            { value = 'remote', display = 'Remote Changes' },
        },
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                M.apply_changes(file_path, entry.value == 'local' and local_changes or remote_changes)
            end)
            return true
        end,
    }

    require('telescope.pickers').new(opts, {
        finder = require('telescope.finders').new_table({
            results = opts.entries,
            entry_maker = function(entry)
                return {
                    value = entry.value,
                    display = entry.display,
                    ordinal = entry.display,
                }
            end,
        }),
        sorter = require('telescope.config').values.generic_sorter(opts),
    }):find()
end

function M.apply_changes(file_path, changes)
    -- Write the selected changes to the file
    local new_content = {}
    local in_conflict = false

    for _, line in ipairs(vim.fn.readfile(file_path)) do
        if line:match('^<<<<<<<') then
            in_conflict = true
        elseif line:match('^=======') then
            -- Skip the conflict markers
        elseif line:match('^>>>>>>>') then
            in_conflict = false
        else
            if not in_conflict then
                table.insert(new_content, line)
            end
        end
    end

    -- Insert the selected changes
    for _, line in ipairs(changes) do
        table.insert(new_content, line)
    end

    -- Write the new content to the file
    vim.fn.writefile(new_content, file_path)

    print("Resolved conflict in " .. file_path)
end

return M
