local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local sorter = require("telescope.sorters")

local M = {}

---@class typstnote.Configuration
---@field note_root string Note root directory. (default: research/)
---@field paper_directory string Where your notes on papers will be stored. (default: <root>/papers/)
---@field idea_directory string Where your notes on ideas will be stored. (default: <root>/ideas/)
---@field register string register to yank to. (default: 'z')
---@field create_gitkeep boolean If `.gitkeep` files should be generated in the directories. (default: true)
---@field bib_path string path to your references.bib (dafault: refreences.bib)

M.default_config = {
	note_root = "research",
	paper_directory = "papers",
	idea_directory = "ideas",
	create_gitkeep = true,
	register = "z",
	bib_path = "research.bib",
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

--- Parse a single BibTeX entry into a Lua table.
---@param entry string A raw BibTeX entry block
---@return table parsed A structured table with type, key, and fields
local parse_bib_entry = function(entry)
	local entry_type, key = entry:match("@(%w+){(.-),")
	local fields = {}

	for field, value in entry:gmatch('([%w]+)%s*=%s*[{"](.-)[}"],') do
		-- Remove any curly braces left inside values
		value = value:gsub("[{}]", "")
		fields[field] = value
	end

	return {
		type = entry_type,
		key = key,
		fields = fields,
	}
end

M.pick_entry = function(opts)
	opts = opts or {}
	opts.bib_path = opts.bib_path or "references.bib"
	opts.cwd = opts.cwd or vim.uv.cwd()

	local finder = finders.new_async_job({
		command_generator = function(prompt)
			if not prompt or prompt == "" then
				prompt = "@"
			end
			local args = { "rg" }
			table.insert(args, "-e")
			table.insert(args, prompt)
			table.insert(args, "-g")
			table.insert(args, opts.bib_path)
			return vim.iter({
				args,
				{
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
					"--smart-case",
				},
			})
				:flatten()
				:totable()
		end,
		entry_maker = make_entry.gen_from_vimgrep(opts),
		cwd = opts.cwd,
	})

	pickers
		.new(opts, {
			prompt_title = "BibTex Search",
			finder = finder,
			previewer = conf.grep_previewer(opts),
			sorter = sorter.get_generic_fuzzy_sorter(opts),
			attach_mappings = function(_, map)
				map({ "i", "n" }, "<CR>", function()
					local selection = action_state.get_selected_entry()

					for _, selected in ipairs(selection) do
						local splits = vim.fn.split(selected, ":")
						local lnum = tonumber(splits[2])

						local abs = vim.fn.fnamemodify(opts.bib_path, ":p")

						vim.cmd.vsplit()
						vim.cmd.edit(abs)

						vim.api.nvim_win_set_cursor(0, { lnum, 0 })
						vim.cmd.normal("zz")
						vim.cmd.normal('vap"' .. M.default_config.register .. "y")

						vim.cmd.bdelete()
						vim.cmd.stopinsert()
						local s = vim.fn.getreg("z")

						local entry = parse_bib_entry(s)

						print(M.create_template_string(entry.key, entry.fields.title, entry.fields.abstract))
					end
				end, { desc = "Create a new paper note file" })
				return true
			end,
		})
		:find()
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

vim.api.nvim_create_user_command("SearchBibTex", function()
	M.pick_entry()
end, {})

M.create_template_string = function(cite_key, title, abstract)
	cite_key = cite_key or "Note5GlossaryNumba"
	title = title or "Towards Improved Modelling"
	abstract = abstract or "#lorem(80)"

	return [[
#show: doc => conf(
  id: "]] .. cite_key .. [[",
  title: []] .. title .. " @" .. cite_key .. [[],
  abstract: ]] .. abstract .. [[,
  doc,
)

= Notes <]] .. cite_key .. [[>
- #lorem(10)

= Ideas
- #lorem(10)

#bibliography("../references.bib")
]]
end

M.pick_entry()

return M
