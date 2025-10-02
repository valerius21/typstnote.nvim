local M = {}

---@class typstnote.Configuration
---@field note_root string Note root directory. (default: research/)
---@field paper_directory string Where your notes on papers will be stored. (default: <root>/papers/)
---@field idea_directory string Where your notes on ideas will be stored. (default: <root>/ideas/)

M.default_config = {
	note_root = "research",
	paper_directory = "papers",
	idea_directory = "ideas",
}

--- Sets the paths for the creation
---@param config typstnote.Configuration?
---@return typstnote.Configuration
M.init_config = function(config)
	config = config or M.default_config
	config.paper_directory = config.note_root .. "/" .. config.paper_directory
	config.idea_directory = config.note_root .. "/" .. config.idea_directory

	return config
end

--- Setup function for Lazyvim
---@param opts typstnote.Configuration? Plugin configuration
M.setup = function(opts)
	opts = opts or {
		note_root = "research",
		paper_directory = "papers",
		idea_directory = "papers",
	}

	opts.paper_directory = opts.note_root .. "/" .. opts.paper_directory
	opts.idea_directory = opts.note_root .. "/" .. opts.idea_directory

	-- user configuration
	print("[typstnote.nvim] called setup")
end

--- Creates all necessary directories in the current folder
--- @param config typstnote.Configuration For the nodes. Default: research/, research/papers, research/ideas
M.create_directories = function(config)
	local directories = {
		config.note_root,
		config.paper_directory,
		config.idea_directory,
	}

	for _, dir in ipairs(directories) do
		local path = vim.fs.root(0, ".git") .. "/" .. dir
		print(path)
		os.execute("mkdir -p " .. path)
		os.execute("touch " .. path .. "/.gitkeep")
	end
	print("directories initialized")
end

vim.api.nvim_create_user_command("CreateDirectories", function()
	local config = M.init_config()
	M.create_directories(config)
end, {})

return M
