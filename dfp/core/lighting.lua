local lighting = {}

lighting.pass = function(node, render_data, camera)

	local window_w = render.get_window_width()
	local window_h = render.get_window_height()
	local viewport = vmath.vector4(
		camera.viewport.x * window_w,
		camera.viewport.y * window_h,
		camera.viewport.z * window_w,
		camera.viewport.w * window_h)

	local camera_proj = vmath.matrix4_perspective(camera.fov, window_w / window_h, camera.near, camera.far)
		
	render.enable_state(render.STATE_BLEND)
	render.enable_state(render.STATE_CULL_FACE)
	render.enable_state(render.STATE_DEPTH_TEST)
	render.set_depth_mask(true)
	render.set_view(camera.view)
	render.set_projection(camera_proj)
	render.set_viewport(viewport.x, viewport.y, viewport.z, viewport.w)

	if camera.clear then
		render.clear({
			[render.BUFFER_COLOR_BIT]   = camera.clear_color,
			[render.BUFFER_DEPTH_BIT]   = camera.clear_depth,
			[render.BUFFER_STENCIL_BIT] = camera.clear_stencil})
	end
	
	render.draw(node.predicates)
end

return lighting