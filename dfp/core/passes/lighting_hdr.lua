local dfp_helpers   = require 'dfp.core.helpers'
local dfp_constants = require 'dfp.core.constants'
local dfp_pass      = require 'dfp.core.pass'

local lighting_hdr = {}

lighting_hdr.make_pass = function(target, textures)
	local pass              = dfp_pass.default()
	pass.target             = target
	pass.textures           = textures
	pass.predicate          = render.predicate({dfp_constants.material_keys.TONEMAPPING_PASS})
	pass.material           = dfp_constants.material_keys.TONEMAPPING_PASS
	pass.execute            = lighting_hdr.execute
	pass.constants          = render.constant_buffer()
	pass.constants.exposure = vmath.vector4(0.5,0,0,0)
	return pass
end

lighting_hdr.execute = function(pass, render_data, camera)
	pass.constants.exposure = vmath.vector4(camera.exposure, 0, 0, 0)
	dfp_pass.execute(pass)
end

return lighting_hdr