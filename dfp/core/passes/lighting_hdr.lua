local dfp_helpers        = require 'dfp.core.helpers'
local dfp_constants      = require 'dfp.core.constants'
local dfp_pass           = require 'dfp.core.pass'
local dfp_log            = require 'dfp.core.log'
local dfp_postprocessing = require 'dfp.core.passes.postprocessing'

local lighting_hdr = {}

lighting_hdr.resize = function(pass)
	dfp_pass.resize_target(pass.target)
end

lighting_hdr.dispose = function(pass)
	dfp_pass.dispose_target(pass.target)
end

lighting_hdr.make_pass = function(state)
	if not state.config[dfp_constants.config_keys.LIGHTING] then
		return
	end

	if not state.config[dfp_constants.config_keys.LIGHTING_HDR] then
		return
	end

	dfp_log("Creating pass lighting_hdr")

	local textures = nil
	local target = nil
	if state.config[dfp_constants.config_keys.SHADOWS] then
		textures = {[0] = state:get_render_pass(dfp_constants.pass_keys.LIGHTING).target}
	end

	if dfp_postprocessing.has_config_values(state.config) then
		target = dfp_pass.make_target(render.get_window_width(), render.get_window_height(), {
			[render.BUFFER_COLOR_BIT] = { format = render.FORMAT_RGBA }
		})
	end
	
	local pass     = dfp_pass.default(dfp_constants.pass_keys.LIGHTING_HDR)
	pass.target    = target
	pass.textures  = textures
	pass.predicate = render.predicate({dfp_constants.material_keys.TONEMAPPING_PASS})
	pass.material  = dfp_constants.material_keys.TONEMAPPING_PASS
	pass.execute   = lighting_hdr.execute
	pass.constants = render.constant_buffer()

	state:register_render_pass(pass)
end

lighting_hdr.execute = function(pass, render_data, camera)
	pass.constants.exposure = vmath.vector4(camera.exposure, 0, 0, 0)
	dfp_pass.execute(pass)
end

return lighting_hdr