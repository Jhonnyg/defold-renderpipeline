local pp = {}

pp.make_target = function(w, h, dfp_config)
	local color_fmt = render.FORMAT_RGBA
	local color_params = {
		format     = color_fmt,
		width      = w,
		height     = h,
		min_filter = render.FILTER_LINEAR,
		mag_filter = render.FILTER_LINEAR,
		u_wrap     = render.WRAP_CLAMP_TO_EDGE,
		v_wrap     = render.WRAP_CLAMP_TO_EDGE
	}
	return render.render_target({[render.BUFFER_COLOR_BIT] = color_params})
end

pp.pass = function(node, parent, render_data, camera)
	render.disable_state(render.STATE_DEPTH_TEST)
	render.disable_state(render.STATE_STENCIL_TEST)
	render.disable_state(render.STATE_BLEND)

	if node.target ~= nil then
		local rw = render.get_render_target_width(node.target, render.BUFFER_COLOR_BIT)
		local rh = render.get_render_target_height(node.target, render.BUFFER_COLOR_BIT)

		render.set_viewport(0, 0, rw, rh)
		render.set_render_target(node.target)
	else
		render.set_render_target(render.RENDER_TARGET_DEFAULT)
	end
	render.enable_material(node.material)

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

	if node.target ~= nil then
		render.set_render_target(render.RENDER_TARGET_DEFAULT)
	end
end

pp.pass_bloom = function(node, parent, render_data, camera)
	local bloom_radius                  = render_data.postprocessing_bloom.filter_radius
	local bloom_strength                = render_data.postprocessing_bloom.strength
	node.constant_buffer.u_bloom_params = vmath.vector4(bloom_radius, bloom_strength, 0, 0)
	
	render.disable_state(render.STATE_DEPTH_TEST)
	render.disable_state(render.STATE_STENCIL_TEST)
	render.disable_state(render.STATE_BLEND)

	local downsample_input_texture   = node.textures[1]
	local downsample_input_texture_w = render.get_render_target_width(downsample_input_texture, render.BUFFER_COLOR_BIT)
	local downsample_input_texture_h = render.get_render_target_height(downsample_input_texture, render.BUFFER_COLOR_BIT)

	render.enable_material(node.material_downsample)
	
	-- downsample target x times
	for k, v in pairs(node.targets_downsample) do
		local rt_w = render.get_render_target_width(v, render.BUFFER_COLOR_BIT)
		local rt_h = render.get_render_target_height(v, render.BUFFER_COLOR_BIT)

		node.constant_buffer.tex_resolution = vmath.vector4(downsample_input_texture_w, downsample_input_texture_h, 0, 0)
		
		render.set_viewport(0, 0, rt_w, rt_h)
		render.set_render_target(v)
		render.clear({[render.BUFFER_COLOR_BIT] = vmath.vector4(0,0,0,0)})
		render.enable_texture(0, downsample_input_texture, render.BUFFER_COLOR_BIT)
		render.draw(node.predicate_downsample, {constants = node.constant_buffer})
		render.disable_texture(0)
		render.set_render_target(render.RENDER_TARGET_DEFAULT)

		downsample_input_texture = v
		downsample_input_texture_w = rt_w
		downsample_input_texture_h = rt_h
	end

	-- render.disable_material()


	render.enable_material(node.material_upsample)

	-- Enable additive blending
	render.enable_state(render.STATE_BLEND)
	render.set_blend_func(render.BLEND_ONE, render.BLEND_ONE)
	
	local upsample_input_texture = downsample_input_texture
	
	for i = #node.targets_downsample-1, 1, -1 do

		local rt = node.targets_downsample[i]
		local rt_w = render.get_render_target_width(rt, render.BUFFER_COLOR_BIT)
		local rt_h = render.get_render_target_height(rt, render.BUFFER_COLOR_BIT)

		-- print(i, rt_w, rt_h)
		--node.constant_buffer.tex_resolution = vmath.vector4(downsample_input_texture_w, downsample_input_texture_h, 0, 0)
		
		render.set_viewport(0, 0, rt_w, rt_h)
		render.set_render_target(rt)
		render.clear({[render.BUFFER_COLOR_BIT] = vmath.vector4(0,0,0,0)})
		render.enable_texture(0, upsample_input_texture, render.BUFFER_COLOR_BIT)
		render.draw(node.predicate_upsample, {constants = node.constant_buffer})
		render.disable_texture(0)
		render.set_render_target(render.RENDER_TARGET_DEFAULT)

		upsample_input_texture = rt
	end

	render.disable_material()

	-- draw and apply bloom filter
	render.set_render_target(node.target)

	-- TODO: this should be passed in via 'camera' argument or something similar
	local viewport_w = render.get_window_width()
	local viewport_h = render.get_window_height()

	if node.target then
		viewport_w = render.get_render_target_height(node.target, render.BUFFER_COLOR_BIT)
		viewport_h = render.get_render_target_height(node.target, render.BUFFER_COLOR_BIT)
	end

	render.set_viewport(0, 0, viewport_w, viewport_h)	
	render.enable_material(node.material)
	render.enable_texture(0, upsample_input_texture, render.BUFFER_COLOR_BIT)

	for k, v in pairs(node.textures) do
		render.enable_texture(k, v, render.BUFFER_COLOR_BIT)
	end

	render.draw(node.predicate, {constants = node.constant_buffer})
	render.disable_texture(0)
	for k, v in pairs(node.textures) do
		render.disable_texture(k)
	end
	render.disable_material()
	render.set_render_target(render.RENDER_TARGET_DEFAULT)
end

return pp