local dfp_constants = require 'dfp.core.constants'
local dfp_helpers   = require 'dfp.core.helpers'
local dfp_pass      = require 'dfp.core.pass'
local dfp_log       = require 'dfp.core.log'

local shadows = {}
shadows.execute = function(pass, render_data, camera)
	local main_light = dfp_helpers.get_main_light(render_data)
	if main_light == nil then
		return
	end
	local light_mtx_view       = dfp_helpers.get_view_matrix_from_light(main_light)
	local light_mtx_projection = dfp_helpers.get_projection_matrix_from_light(main_light)

	pass.view       = light_mtx_view
	pass.projection = light_mtx_projection

	dfp_pass.execute(pass)
end

shadows.dispose = function(pass)
	dfp_log("Disposing pass shadows")
	dfp_pass.dispose_target(pass.target)
end

shadows.make_pass = function(state)
	if not state.config[dfp_constants.config_keys.SHADOWS] then
		return
	end

	dfp_log("Creating pass shadows")

	local size           = state.config[dfp_constants.config_keys.SHADOWS_SHADOW_MAP_SIZE]
	local target_buffers = {
		[render.BUFFER_DEPTH_BIT] = {format = render.FORMAT_DEPTH},
		[render.BUFFER_COLOR_BIT] = {format = render.FORMAT_R32F}
	}
	local target   = dfp_pass.make_target(size, size, target_buffers)
	local pass     = dfp_pass.default(dfp_constants.pass_keys.pass_shadows)
	pass.execute   = shadows.execute
	pass.dispose   = shadows.dispose
	pass.predicate = render.predicate({dfp_constants.material_keys.SCENE_PASS})
	pass.material  = dfp_constants.material_keys.SHADOW_PASS
	pass.target    = target
	pass.viewport  = vmath.vector4(0, 0,
		render.get_render_target_width(target, render.BUFFER_COLOR0_BIT),
		render.get_render_target_height(target, render.BUFFER_COLOR0_BIT))

	pass.pipeline.depth       = true
	pass.pipeline.depth_mask  = true
	pass.pipeline.depth_fn    = render.COMPARE_FUNC_LEQUAL
	pass.pipeline.cull        = false
	pass.pipeline.blend       = false
	pass.pipeline.clear       = true
	pass.pipeline.clear_table = {
		[render.BUFFER_COLOR_BIT] = vmath.vector4(0,0,0,1),
		[render.BUFFER_DEPTH_BIT] = 1
	}

	state:register_render_pass(pass)
end

return shadows