local dfp_helpers   = require 'dfp.core.helpers'
local dfp_constants = require 'dfp.core.constants'

local lighting = {}

local function make_target(w,h, color_format, use_depth)
	local color_params = {
		format     = color_format,
		width      = w,
		height     = h,
		min_filter = render.FILTER_LINEAR,
		mag_filter = render.FILTER_LINEAR,
		u_wrap     = render.WRAP_CLAMP_TO_EDGE,
		v_wrap     = render.WRAP_CLAMP_TO_EDGE
	}

	local depth_params = nil

	if use_depth then
		depth_params = { 
			format        = render.FORMAT_DEPTH,
			width         = w,
			height        = h,
			min_filter    = render.FILTER_NEAREST,
			mag_filter    = render.FILTER_NEAREST,
			u_wrap        = render.WRAP_CLAMP_TO_EDGE,
			v_wrap        = render.WRAP_CLAMP_TO_EDGE
		}
	end

	return render.render_target({
		[render.BUFFER_COLOR_BIT] = color_params,
		[render.BUFFER_DEPTH_BIT] = depth_params
	})
end

lighting.make_target = function(w, h, dfp_config)
	local color_fmt = render.FORMAT_RGBA

	if dfp_config[dfp_constants.config_keys.LIGHTING_HDR] then
		color_fmt = render.FORMAT_RGBA32F
	end

	return make_target(w, h, color_fmt, true)
end

lighting.make_target_hdr = function(w, h, dfp_config)
	return make_target(w, h, render.FORMAT_RGBA, false)
end

lighting.pass = function(node, parent, render_data, camera)

	local window_w = render.get_window_width()
	local window_h = render.get_window_height()
	local viewport = vmath.vector4(
		camera.viewport.x * window_w,
		camera.viewport.y * window_h,
		camera.viewport.z * window_w,
		camera.viewport.w * window_h)

	local camera_proj    = vmath.matrix4_perspective(camera.fov, window_w / window_h, camera.near, camera.far)
	local main_light_mtx = vmath.matrix4()
	local main_light     = dfp_helpers.get_main_light(render_data)
	local light          = vmath.vector4()

	if main_light ~= nil then
		local main_light_view       = dfp_helpers.get_view_matrix_from_light(main_light)
		local main_light_projection = dfp_helpers.get_projection_matrix_from_light(main_light)
		local main_light_inv        = vmath.inv(main_light_view)

		main_light_mtx = node.bias_matrix * main_light_projection * main_light_view
		light.x = main_light_inv.m03
		light.y = main_light_inv.m13
		light.z = main_light_inv.m23
		light.w = 1
	end

	node.constant_buffer.mtx_light_mvp0 = main_light_mtx.c0
	node.constant_buffer.mtx_light_mvp1 = main_light_mtx.c1
	node.constant_buffer.mtx_light_mvp2 = main_light_mtx.c2
	node.constant_buffer.mtx_light_mvp3 = main_light_mtx.c3
	node.constant_buffer.light          = light
		
	render.enable_state(render.STATE_BLEND)
	render.enable_state(render.STATE_CULL_FACE)
	render.enable_state(render.STATE_DEPTH_TEST)
	render.set_depth_mask(true)
	render.set_view(camera.view)
	render.set_projection(camera_proj)
	render.set_viewport(viewport.x, viewport.y, viewport.z, viewport.w)

	if node.shadow_buffer ~= nil then
		render.enable_texture(1, node.shadow_buffer, render.BUFFER_COLOR_BIT)
	end

	if node.target ~= nil then
		render.set_render_target(node.target)
	end
	
	if camera.clear then
		render.clear({
			[render.BUFFER_COLOR_BIT]   = camera.clear_color,
			[render.BUFFER_DEPTH_BIT]   = camera.clear_depth,
			[render.BUFFER_STENCIL_BIT] = camera.clear_stencil})
	end

	render.draw(node.predicates, { constants = node.constant_buffer })
	render.disable_texture(1)

	if node.target ~= nil then
		render.set_render_target(render.RENDER_TARGET_DEFAULT)
	end
end

lighting.pass_hdr = function(node, parent, render_data, camera)
	render.disable_state(render.STATE_BLEND)
	render.disable_state(render.STATE_CULL_FACE)
	render.disable_state(render.STATE_DEPTH_TEST)
	render.set_depth_mask(false)

	--pprint(parent.target)

	render.set_render_target(node.target)

	--render.enable_material(node.material)
	render.enable_texture(0, parent.target, render.BUFFER_COLOR_BIT)
	render.draw(node.predicates, { constants = node.constant_buffer })
	render.disable_texture(0)
	--render.disable_material()

	render.set_render_target(render.RENDER_TARGET_DEFAULT)
end

return lighting