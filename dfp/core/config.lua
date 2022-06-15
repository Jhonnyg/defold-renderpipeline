local dfp_constants = require 'dfp.core.constants'

local config = {}

config.default = function()
	return {
		[dfp_constants.config_keys.LIGHTING]                     = true,
		[dfp_constants.config_keys.LIGHTING_MAX_FRAGMENT_LIGHTS] = 2,
		[dfp_constants.config_keys.LIGHTING_MAX_VERTEX_LIGHTS]   = 4,
		[dfp_constants.config_keys.SHADOWS]                      = true,
		[dfp_constants.config_keys.SHADOWS_SHADOW_MAP_SIZE]      = 1024,
	}
end

return config