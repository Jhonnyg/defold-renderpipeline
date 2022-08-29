
local pass = {}
local current_pipeline = nil

local function needs_change(key, pipeline)
	return pipeline[key] ~= nil and pipeline[key] ~= current_pipeline[key]
end

local function set_state(state, value)
	if value then
		render.enable_state(state)
	else
		render.disable_state(state)
	end
end

local function set_state_if_changed(key, pipeline, state)
	if needs_change(key, pipeline) then
		set_state(state, pipeline[key])
		current_pipeline[key] = pipeline[key]
	end
end

local function set_pipeline(pipeline)
	set_state_if_changed("blend", pipeline, render.STATE_BLEND)
	set_state_if_changed("depth", pipeline, render.STATE_DEPTH_TEST)
	set_state_if_changed("cull", pipeline, render.STATE_CULL_FACE)

	if needs_change("blend_src", pipeline) or needs_change("blend_dst", pipeline) then
		render.set_blend_func(pipeline.blend_src, pipeline.blend_dst)
		current_pipeline.blend_src = pipeline.blend_src
		current_pipeline.blend_dst = pipeline.blend_dst
	end

	if needs_change("cull_fn", pipeline) then
		render.set_cull_face(pipeline.cull_fn)
		current_pipeline.cull_fn = pipeline.cull_fn
	end

	if needs_change("depth_fn", pipeline) then
		render.set_depth_func(pipeline.depth_fn)
		current_pipeline.depth_fn = pipeline.depth_fn
	end

	if needs_change("depth_mask", pipeline) then
		render.set_depth_mask(pipeline.depth_mask)
		current_pipeline.depth_mask = pipeline.depth_mask
	end

	if pipeline.clear ~= nil then
		local clear_table = {}

		for k, v in pairs(pipeline.clear_table) do
			clear_table[k] = v
			current_pipeline.clear_table[k] = v
		end
		
		render.clear(clear_table)
		current_pipeline.clear = pipeline.clear
	end
end

pass.begin_frame = function()
	current_pipeline = pass.default_pipeline()
	render.set_blend_func(current_pipeline.blend_src, current_pipeline.blend_dst)
	render.set_color_mask(true, true, true, true) -- not supported yet
	render.set_cull_face(current_pipeline.cull_fn)
	render.set_depth_func(current_pipeline.depth_fn)
	render.set_depth_mask(current_pipeline.depth_mask)
	render.set_projection(vmath.matrix4())
	render.set_render_target(render.RENDER_TARGET_DEFAULT)
	render.set_stencil_func(current_pipeline.stencil_func, current_pipeline.stencil_ref, current_pipeline.stencil_mask)
	render.set_view(vmath.matrix4())
	render.set_viewport(0, 0, render.get_window_width(), render.get_window_width())
	render.disable_material()

	set_state(render.STATE_BLEND, current_pipeline.blend)
	set_state(render.STATE_CULL_FACE, current_pipeline.cull)
	set_state(render.STATE_DEPTH_TEST, current_pipeline.depth)
	set_state(render.STATE_STENCIL_TEST, current_pipeline.stencil)
end

--[[--
pass_desc = {
	material,
	predicate,
	constants,
	target,
	view,
	projection,
	pipeline,
	textures
}
--]]--

pass.execute = function(pass_desc, do_print)
	if pass_desc.target ~= nil then
		render.set_render_target(pass_desc.target)
	end

	set_pipeline(pass_desc.pipeline)
	
	if pass_desc.material ~= nil then
		render.enable_material(pass_desc.material)
	end

	if pass_desc.view ~= nil then
		render.set_view(pass_desc.view)
	end

	if pass_desc.projection ~= nil then
		render.set_projection(pass_desc.projection)
	end

	if pass_desc.textures ~= nil then
		for k, v in pairs(pass_desc.textures) do
			render.enable_texture(k, v, render.BUFFER_COLOR_BIT)
		end
	end

	if pass_desc.viewport ~= nil then
		render.set_viewport(pass_desc.viewport.x, pass_desc.viewport.y, pass_desc.viewport.z, pass_desc.viewport.w)
	end

	render.draw(pass_desc.predicate, { constants = pass_desc.constants })

	if pass_desc.textures ~= nil then
		for k, v in pairs(pass_desc.textures) do
			render.disable_texture(k)
		end
	end

	if pass_desc.material ~= nil then
		render.disable_material()
	end

	if pass_desc.target ~= nil then
		render.set_render_target(render.RENDER_TARGET_DEFAULT)
	end
end

pass.default_pipeline = function()
	return {
		blend         = false,
		blend_src     = render.BLEND_SRC_ALPHA,
		blend_dst     = render.BLEND_ONE_MINUS_SRC_ALPHA,
		clear         = true,
		clear_table   = { [render.BUFFER_COLOR_BIT] = vmath.vector4(), [render.BUFFER_DEPTH_BIT] = 1, [render.BUFFER_STENCIL_BIT] = 0 },
		cull          = false,
		cull_fn       = render.FACE_BACK,
		depth 	      = false,
		depth_fn      = render.COMPARE_FUNC_LESS,
		depth_mask    = false,
		stencil       = false,
		stencil_func  = render.COMPARE_FUNC_ALWAYS,
		stencil_ref   = 0,
		stencil_mask  = 255
	}
end

pass.default = function(pass_key)
	return {
		pass_key   = pass_key,
		material   = nil,
		predicate  = nil,
		constants  = nil,
		viewport   = nil,
		execute    = pass.execute,
		resize     = function() end,
		dispose    = function() end,
		target     = render.RENDER_TARGET_DEFAULT,
		view       = vmath.matrix4(),
		projection = vmath.matrix4(),
		pipeline   = pass.default_pipeline(),
		textures   = {},
	} 
end

pass.make_target = function(w, h, buffers)
	local target_buffers = {}
	for k, v in pairs(buffers) do
		target_buffers[k] = {
			format     = v.format,
			width      = w,
			height     = h,
			min_filter = render.FILTER_LINEAR,
			mag_filter = render.FILTER_LINEAR,
			u_wrap     = render.WRAP_CLAMP_TO_EDGE,
			v_wrap     = render.WRAP_CLAMP_TO_EDGE
		}
	end
	return render.render_target(target_buffers)
end

pass.dispose_target = function(rt)
	if rt ~= nil then
		render.delete_render_target(rt)
	end
end

pass.resize_target = function(rt, w, h)
	if rt ~= nil then
		local current_w = render.get_render_target_width(rt, render.BUFFER_COLOR_BIT)
		local current_h = render.get_render_target_height(rt, render.BUFFER_COLOR_BIT)
		if current_w ~= w or current_h ~= h then
			render.set_render_target_size(rt, w, h)
		end
	end
end

return pass
