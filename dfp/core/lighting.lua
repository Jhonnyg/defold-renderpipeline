local dfp_helpers = require 'dfp.core.helpers'

local lighting = {}

lighting.make_target = function(w, h)
	local color_params = {
		format     = render.FORMAT_RGBA,
		width      = w,
		height     = h,
		min_filter = render.FILTER_NEAREST,
		mag_filter = render.FILTER_NEAREST,
		u_wrap     = render.WRAP_CLAMP_TO_EDGE,
		v_wrap     = render.WRAP_CLAMP_TO_EDGE
	}

	local depth_params = { 
		format        = render.FORMAT_DEPTH,
		width         = w,
		height        = h,
		min_filter    = render.FILTER_NEAREST,
		mag_filter    = render.FILTER_NEAREST,
		u_wrap        = render.WRAP_CLAMP_TO_EDGE,
		v_wrap        = render.WRAP_CLAMP_TO_EDGE
	}

	return render.render_target({
		[render.BUFFER_COLOR_BIT] = color_params,
		[render.BUFFER_DEPTH_BIT] = depth_params
	})
end

lighting.pass = function(node, render_data, camera)

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

	render.enable_texture(1, node.shadow_buffer, render.BUFFER_COLOR_BIT)

	if camera.clear then
		render.clear({
			[render.BUFFER_COLOR_BIT]   = camera.clear_color,
			[render.BUFFER_DEPTH_BIT]   = camera.clear_depth,
			[render.BUFFER_STENCIL_BIT] = camera.clear_stencil})
	end

	if node.target ~= nil then
		render.set_render_target(node.target)
	end
	render.draw(node.predicates, { constants = node.constant_buffer })
end

return lighting