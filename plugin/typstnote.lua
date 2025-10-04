local typstnote = require("typstnote")

vim.api.nvim_create_user_command("TypstNote", function(cmd_opts)
	local sub = cmd_opts.fargs[1]
	if sub == "init" then
		typstnote.create_directories(typstnote.default_config)
	else
		if sub == "add" then
			typstnote.pick_entry()
		else
			print("Unknown subcommand: " .. sub)
		end
	end
end, { nargs = 1 })
