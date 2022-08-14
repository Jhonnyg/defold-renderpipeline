local graph = {}

local function null_fn() end
local function null_node()
	return {
		execute = null_fn,
		output = nil,
	}
end

graph.node = function(execute_fn, name)
	local n = null_node()
	n.name = "<unknown>"

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

graph.execute = function(node, parent, render_data, camera)
	node.execute(node, parent, render_data, camera)
	if node.output ~= nil then
		graph.execute(node.output, node, render_data, camera)
	end
end

return graph