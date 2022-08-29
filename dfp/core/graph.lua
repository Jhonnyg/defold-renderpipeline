local graph = {}

local function null_fn() end
local function null_node()
	return {
		execute = null_fn,
		output = nil,
	}
end

graph.print = function(root)
	if root == nil then
		return nil
	end
	local node = root
	local depth = 0
	repeat
		local lbl = "|-"
		for i = 0, depth do
			lbl = " " .. lbl
		end
		lbl = lbl .. node.name

		lbl_flags = {}
		if not node.enabled then
			table.insert(lbl_flags, "disabled")
		end

		if #lbl_flags > 0 then
			lbl_flags_str = " (" .. table.concat(lbl_flags, "|") .. ")"
			lbl = lbl .. lbl_flags_str
		end

		depth = depth + 1
		print(lbl)
		node = node.output
	until node == nil
end

graph.get_node = function(root, node_key)
	if root == nil then
		return nil
	end
	local node = root
	repeat
		if node.name == node_key then
			return node
		end
		node = node.output
	until node == nil
end

graph.get_parent = function(root, node_key)
	if root == nil then
		return nil
	end
	local node = root
	local node_parent = nil
	repeat
		if node.name == node_key then
			return node_parent
		end
		node_parent = node
		node = node.output
	until node == nil
end

graph.node = function(execute_fn, name)
	local n = null_node()
	n.name = "<unknown>"
	n.enabled = true
	
	if name ~= nil then
		n.name = name
	end	
	if execute_fn ~= nil then
		n.execute = execute_fn
	end
	return n
end

graph.set_output = function(node, node_output)
	node.output = node_output
end

graph.set_enabled = function(node, flag)
	if node ~= nil then
		if node.enabled ~= flag then
			print("Setting node visibility for " .. node.name .. " to " .. tostring(flag))
			node.enabled = flag
		end
	end
end

graph.execute = function(node, parent, render_data, camera)
	if node.enabled then
		node.execute(node, parent, render_data, camera)
	end
	if node.output ~= nil then
		graph.execute(node.output, node, render_data, camera)
	end
end

return graph