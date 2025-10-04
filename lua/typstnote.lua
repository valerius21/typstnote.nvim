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

M.config = {
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
	if config == nil then
		config = M.config
	end
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
		local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
		if vim.v.shell_error ~= 0 or not git_root or git_root == "" then
			error("Not in a git repository", vim.log.levels.ERROR)
			return
		end
		local path = git_root .. "/" .. dir

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
						vim.cmd.normal('vap"' .. M.config.register .. "y")

						vim.cmd.bdelete()
						vim.cmd.stopinsert()
						local s = vim.fn.getreg("z")

						local entry = parse_bib_entry(s)

						M.add_paper_note(entry)
					end
				end, { desc = "Create a new paper note file" })
				return true
			end,
		})
		:find()
end

M.create_template_string = function(cite_key, title, abstract, include_bib)
	cite_key = cite_key or "no_cite_key"
	title = title or "No Title"
	if abstract then
		abstract = "[" .. abstract .. "]"
	else
		abstract = "lorem(80)"
	end
	local bib_str
	if include_bib == nil or include_bib then
		bib_str = '#bibliography("../../references.bib")' -- TODO: robust path
	else
		bib_str = ""
	end

	return [[
#import "_paper.typ": conf

#show: doc => conf(
  id: "]] .. cite_key .. [[",
  title: []] .. title .. " @" .. cite_key .. [[],
  abstract: ]] .. abstract .. [[,
  doc,
)

= Notes <notes_]] .. M.remove_at_symbol(cite_key) .. [[>
- #lorem(10)

= Ideas <ideas_]] .. M.remove_at_symbol(cite_key) .. [[>
- #lorem(10)

]] .. bib_str
end

M.remove_at_symbol = function(str)
	return str:gsub("@", "")
end

--- Create a new paper note file based on a BibTeX entry
--- @param entry table A parsed BibTeX entry with fields `key`, `title`, and `abstract`
M.add_paper_note = function(entry)
	-- check if papers directory exists

	if vim.fn.isdirectory(M.config.paper_directory) == 0 then
		print("Papers directory does not exist. Creating directories...")
		M.create_directories(M.config)
	end

	-- copy _paper.typ to papers directory if it doesn't exist
	local paper_typ_path = M.config.paper_directory .. "/_paper.typ"
	if vim.fn.filereadable(paper_typ_path) == 0 then
		local source_path = vim.fn.expand("%:p:h") .. "/../typst/_paper.typ"
		if vim.fn.filereadable(source_path) == 1 then
			os.execute("cp " .. source_path .. " " .. paper_typ_path)
			print("_paper.typ copied to papers directory.")
		else
			error("Source _paper.typ not found in config/typst/. Please create it manually.", vim.log.levels.ERROR)
		end
	end

	-- write the created template in a file named after the cite key in the papers directory
	local file_path = M.config.paper_directory .. "/" .. entry.key .. ".typ"
	local file = io.open(file_path, "w")
	if file then
		local content = M.create_template_string(entry.key, entry.fields.title, entry.fields.abstract)
		file:write(content)
		file:close()
		print("Paper note created at " .. file_path)
	else
		error("Error creating file at " .. file_path, vim.log.levels.ERROR)
	end
end

---@param opts typstnote.Configuration? Plugin configuration
--- Setup function for Lazyvim
M.setup = function(opts)
	opts = M.init_config(opts)
end

return M
