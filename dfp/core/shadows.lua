local dfp_helpers = require 'dfp.core.helpers'

local shadows = {}

shadows.make_target = function(w, h)
	local color_params = {
		format     = render.FORMAT_R32F,
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

shadows.pass = function(node, parent, render_data, camera)
	local main_light = dfp_helpers.get_main_light(render_data)
	if main_light == nil then
		return
	end

	local light_mtx_view = dfp_helpers.get_view_matrix_from_light(main_light)
	local light_mtx_projection = dfp_helpers.get_projection_matrix_from_light(main_light)

	local viewport_w = render.get_render_target_width(node.target, render.BUFFER_DEPTH_BIT)
	local viewport_h = render.get_render_target_height(node.target, render.BUFFER_DEPTH_BIT)
	
	render.set_depth_mask(true)
	render.set_depth_func(render.COMPARE_FUNC_LEQUAL)
	render.enable_state(render.STATE_DEPTH_TEST)
	render.disable_state(render.STATE_BLEND)
	render.disable_state(render.STATE_CULL_FACE)
	
	render.set_projection(light_mtx_projection)
	render.set_view(light_mtx_view)
	render.set_viewport(0, 0, viewport_w, viewport_h)
	
	render.set_render_target(node.target, { transient = {render.BUFFER_DEPTH_BIT} })
	render.clear({[render.BUFFER_COLOR_BIT] = vmath.vector4(0,0,0,1), [render.BUFFER_DEPTH_BIT] = 1})
	render.enable_material(node.material)
	render.draw(node.predicates)
	render.disable_material()
	render.set_render_target(render.RENDER_TARGET_DEFAULT)
end

return shadows