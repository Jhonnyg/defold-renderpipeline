
local function log(message, opt)
	local indent = ""
	if opt ~= nil then
		if opt.indent then
			for i = 1, opt.indent do
				indent = indent .. " "
			end
		end
	end
	
	pprint("[dfp]  " .. indent .. message)
end

return log