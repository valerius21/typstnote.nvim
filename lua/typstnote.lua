local M = {}

---@class typstnote.Configuration
---@field note_root string Note root directory. (default: research/)
---@field paper_directory string Where your notes on papers will be stored. (default: <root>/papers/)
---@field idea_directory string Where your notes on ideas will be stored. (default: <root>/ideas/)
---@field create_gitkeep boolean If `.gitkeep` files should be generated in the directories. (default: true)

M.default_config = {
	note_root = "research",
	paper_directory = "papers",
	idea_directory = "ideas",
	create_gitkeep = true,
}

--- Sets the paths for the creation
---@param config typstnote.Configuration?
---@return typstnote.Configuration
M.init_config = function(config)
	config = config or M.default_config
	config.paper_directory = config.note_root .. "/" .. config.paper_directory
	config.idea_directory = config.note_root .. "/" .. config.idea_directory
	config.create_gitkeep = true

	return config
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

		os.execute("mkdir -p " .. path)
		print(path)

		if config.create_gitkeep then
			os.execute("touch " .. path .. "/.gitkeep")
		end
	end

	print("directories initialized")
end

---@param opts typstnote.Configuration? Plugin configuration
--- Setup function for Lazyvim
M.setup = function(opts)
	opts = M.init_config(opts)
	-- user configuration
end

vim.api.nvim_create_user_command("CreateDirectories", function()
	local config = M.init_config()
	M.create_directories(config)
end, {})

return M
