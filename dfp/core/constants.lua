local constants = {}

constants.PROPERTY_MAIN_LIGHT           = "main_light"
constants.PROPERTY_VERTEX_LIGHT         = "vertex_light"

constants.PROPERTY_LIGHT_FRUSTUM_SIZE   = "light_frustum_size"
constants.PROPERTY_LIGHT_FRUSTUM_NEAR   = "light_frustum_near"
constants.PROPERTY_LIGHT_FRUSTUM_FAR    = "light_frustum_far"
constants.PROPERTY_LIGHT_BRIGHTNESS     = "light_brightness"

constants.PROPERTY_CAMERA_FOV           = "camera_fov"
constants.PROPERTY_CAMERA_NEAR          = "camera_near"
constants.PROPERTY_CAMERA_FAR           = "camera_far"
constants.PROPERTY_CAMERA_VIEWPORT      = "camera_viewport"
constants.PROPERTY_CAMERA_CLEAR         = "camera_clear"
constants.PROPERTY_CAMERA_CLEAR_COLOR   = "camera_clear_color"
constants.PROPERTY_CAMERA_CLEAR_DEPTH   = "camera_clear_depth"
constants.PROPERTY_CAMERA_CLEAR_STENCIL = "camera_clear_stencil"
constants.PROPERTY_CAMERA_EXPOSURE      = "camera_exposure"

constants.config_keys = {
	NONE                           = 0,
	-- Lights
	LIGHTING                       = 1,
	LIGHTING_MAX_FRAGMENT_LIGHTS   = 2,
	LIGHTING_MAX_VERTEX_LIGHTS     = 3,
	LIGHTING_HDR                   = 4,
	-- Shadows
	SHADOWS                        = 6,
	SHADOWS_SHADOW_MAP_SIZE        = 7,
	-- Post processing
	POSTPROCESSING                 = 8,
	POSTPROCESSING_BLOOM           = 9,
	POSTPROCESSING_BLOOM_STRENGTH  = 10,
	POSTPROCESSING_BLOOM_RADIUS    = 11,
	POSTPROCESSING_DOF             = 12,
}

constants.pass_keys = {
	SHADOWS              = "pass_shadows",
	LIGHTING             = "pass_lighting",
	LIGHTING_HDR         = "pass_lighting_hdr",
	POSTPROCESSING_BLOOM = "pass_postprocessing_bloom",
	POSTPROCESSING_DOF   = "pass_postprocessing_dof",
}

constants.material_keys = {
	SHADOW_PASS           = "dfp_pass_shadow",
	SCENE_PASS            = "dfp_pass_scene",
	TONEMAPPING_PASS      = "dfp_pass_tonemapping",
	BLOOM_PASS            = "dfp_pass_bloom",
	BLOOM_PASS_DOWNSAMPLE = "dfp_pass_bloom_downsample",
	BLOOM_PASS_UPSAMPLE   = "dfp_pass_bloom_upsample",
}

return constants