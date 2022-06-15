local constants = {}

constants.PROPERTY_MAIN_LIGHT   = "main_light"
constants.PROPERTY_VERTEX_LIGHT = "vertex_light"

constants.PROPERTY_CAMERA_FOV           = "camera_fov"
constants.PROPERTY_CAMERA_NEAR          = "camera_near"
constants.PROPERTY_CAMERA_FAR           = "camera_far"
constants.PROPERTY_CAMERA_VIEWPORT      = "camera_viewport"
constants.PROPERTY_CAMERA_CLEAR         = "camera_clear"
constants.PROPERTY_CAMERA_CLEAR_COLOR   = "camera_clear_color"
constants.PROPERTY_CAMERA_CLEAR_DEPTH   = "camera_clear_depth"
constants.PROPERTY_CAMERA_CLEAR_STENCIL = "camera_clear_stencil"

constants.config_keys = {
	NONE                         = 0,
	-- Lights
	LIGHTING                     = 1,
	LIGHTING_MAX_FRAGMENT_LIGHTS = 2,
	LIGHTING_MAX_VERTEX_LIGHTS   = 3,
	-- Shadows
	SHADOWS                      = 4,
	SHADOWS_SHADOW_MAP_SIZE      = 5,
}

constants.material_keys = {
	SHADOW_PASS = "dfp_pass_shadow", -- move to constants
	SCENE_PASS = "dfp_pass_scene",
}

return constants