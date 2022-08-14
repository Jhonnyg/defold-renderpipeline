local pp = {}

pp.pass = function(node, parent, render_data, camera)
	--pprint(node.name, node.predicate)
	render.disable_state(render.STATE_DEPTH_TEST)
	render.disable_state(render.STATE_STENCIL_TEST)
	render.disable_state(render.STATE_BLEND)

	if node.target ~= nil then
		render.set_render_target(node.target)
	else
		render.set_render_target(render.RENDER_TARGET_DEFAULT)
	end
	render.enable_material(node.material)
	
	local rw = render.get_render_target_width(parent.target, render.BUFFER_COLOR_BIT)
	local rh = render.get_render_target_height(parent.target, render.BUFFER_COLOR_BIT)

	render.set_viewport(0, 0, rw, rh)

	if node.textures ~= nil then
		for k, v in pairs(node.textures) do
			render.enable_texture(k - 1, v, render.BUFFER_COLOR_BIT)
		end
	end

	render.clear({[render.BUFFER_COLOR_BIT] = vmath.vector4(0,0,0,0)})
	render.draw(node.predicate)

	if node.textures ~= nil then
		for k, v in pairs(node.textures) do
			render.disable_texture(k - 1)
		end
	end
	
	render.disable_material()
end

return pp