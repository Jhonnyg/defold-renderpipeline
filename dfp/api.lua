local dfp_constants      = require 'dfp.core.constants'
local dfp_config         = require 'dfp.core.config'
local dfp_helpers        = require 'dfp.core.helpers'
local dfp_pass           = require 'dfp.core.pass'
local dfp_shadows        = require 'dfp.core.passes.shadows'
local dfp_lighting       = require 'dfp.core.passes.lighting'
local dfp_lighting_hdr   = require 'dfp.core.passes.lighting_hdr'
local dfp_postprocessing = require 'dfp.core.passes.postprocessing'

local dfp_state = {
	render_init       = false,
	render_graph      = {},
	render_targets    = {},
	render_data       = { cameras = {}, lights = {} },
	render_predicates = {},
	render_passes     = {},
	custom_passes     = {},
	config            = dfp_config.default(),
	lights            = {},
	cameras           = {},
}

local function do_register_render_pass(pass)
	dfp_state:register_render_pass(pass)
end

dfp_state.dispose = function(self)
	for k, v in pairs(self.render_passes) do
		v:dispose()
	end
	self.render_passes = {}
end

dfp_state.get_render_pass = function(self, pass_key)
	for k, v in pairs(self.render_passes) do
		if v.pass_key == pass_key then
			return v
		end
	end
end

dfp_state.rebuild = function(self)
	dfp_state:dispose()
	dfp_shadows.make_pass(dfp_state)
	dfp_lighting.make_pass(dfp_state)
	dfp_lighting_hdr.make_pass(dfp_state)
	dfp_postprocessing.make_pass(dfp_state)
	
end

dfp_state.register_render_pass = function(self, pass)
	table.insert(self.render_passes, pass)
end

dfp_state.resize = function(self)
	for k, v in pairs(self.render_passes) do
		v:resize()
	end
end

dfp_state.render = function(self)
	dfp_pass.begin_frame()
	
	for k, v in pairs(self.render_data.cameras) do
		for pk, pv in pairs(self.render_passes) do
			pv.execute(pv, self.render_data, v)
		end
	end
end

local function init_render()
	for k, v in pairs(dfp_constants.material_keys) do
		dfp_state.render_predicates[k] = render.predicate({v})
	end

	dfp_state:rebuild()
	dfp_state.render_init = true
end

-------------------------------------------
-------------- API functions --------------
-------------------------------------------
local api = {}

api.__register_light = function(cmp)
	table.insert(dfp_state.lights, cmp)
end

api.__register_camera = function(cmp)
	table.insert(dfp_state.cameras, cmp)
end

api.pass_keys = dfp_constants.pass_keys
api.config    = dfp_constants.config_keys

api.configure = function(tbl)
	local configuration_changed = false
	for k, v in pairs(tbl) do
		if dfp_state.config[k] ~= nil then
			dfp_state.config[k] = v
			configuration_changed = true
		end
	end

	dfp_state.config_dirty = configuration_changed
end

-- This must be called from a script component somewhere in a collection
-- TODO: Figure out how to deal with dfp components that live in other collections..
api.update = function()
	dfp_state.render_data = {}
	dfp_state.render_data.cameras = {}
	dfp_state.render_data.lights = {}

	for k, v in pairs(dfp_state.cameras) do
		local c          = {}
		local c_url      = msg.url(nil, v, "dfp_camera")
		local c_fov      = go.get(c_url, dfp_constants.PROPERTY_CAMERA_FOV)
		local c_viewport = go.get(c_url, dfp_constants.PROPERTY_CAMERA_VIEWPORT)
		local c_clear    = go.get(c_url, dfp_constants.PROPERTY_CAMERA_CLEAR)
		local c_clear_c  = go.get(c_url, dfp_constants.PROPERTY_CAMERA_CLEAR_COLOR)
		local c_clear_d  = go.get(c_url, dfp_constants.PROPERTY_CAMERA_CLEAR_DEPTH)
		local c_clear_s  = go.get(c_url, dfp_constants.PROPERTY_CAMERA_CLEAR_STENCIL)
		local c_pos      = go.get_world_position(v)
		local c_rot      = go.get_world_rotation(v)
		
		local c_eye      = c_pos
		local c_look_at  = c_pos + vmath.vector3(0, 0, 1)
		local c_up       = vmath.vector3(0, 1, 0)
		
		c.viewport      = c_viewport
		c.clear         = c_clear
		c.clear_color   = c_clear_c
		c.clear_depth   = c_clear_d
		c.clear_stencil = c_clear_s
		c.fov           = c_fov
		c.near          = go.get(c_url, dfp_constants.PROPERTY_CAMERA_NEAR)
		c.far           = go.get(c_url, dfp_constants.PROPERTY_CAMERA_FAR)
		c.exposure      = go.get(c_url, dfp_constants.PROPERTY_CAMERA_EXPOSURE)
		--c.view          = vmath.inv(vmath.matrix4_from_quat(c_rot) * vmath.matrix4_translation(c_pos))
		c.projection    = vmath.matrix4()

		-- todo: fix this
		c.view = vmath.inv(dfp_helpers.translate_matrix(vmath.matrix4_from_quat(c_rot), c_pos))

		table.insert(dfp_state.render_data.cameras, c)
	end

	if dfp_state.config[dfp_constants.config_keys.POSTPROCESSING_BLOOM] then
		local params = {}
		params.filter_radius = dfp_state.config[dfp_constants.config_keys.POSTPROCESSING_BLOOM_RADIUS]
		params.strength 	 = dfp_state.config[dfp_constants.config_keys.POSTPROCESSING_BLOOM_STRENGTH]
		dfp_state.render_data.postprocessing_bloom = params
	end

	if dfp_state.config[dfp_constants.config_keys.LIGHTING] then
		for k, v in pairs(dfp_state.lights) do
			local lpos          = go.get_position(v)
			local lrot          = go.get_rotation(v)
			local lmainlighturl = msg.url(nil, v, "dfp_light")
			local lmainlight    = go.get(lmainlighturl, dfp_constants.PROPERTY_MAIN_LIGHT)
			local lvertexlight  = go.get(lmainlighturl, dfp_constants.PROPERTY_VERTEX_LIGHT)

			local l_frustum_size = go.get(lmainlighturl, dfp_constants.PROPERTY_LIGHT_FRUSTUM_SIZE)
			local l_frustum_near = go.get(lmainlighturl, dfp_constants.PROPERTY_LIGHT_FRUSTUM_NEAR)
			local l_frustum_far  = go.get(lmainlighturl, dfp_constants.PROPERTY_LIGHT_FRUSTUM_FAR)
			local l_brightness   = go.get(lmainlighturl, dfp_constants.PROPERTY_LIGHT_BRIGHTNESS)
			
			table.insert(dfp_state.render_data.lights, {
				position = lpos,
				rotation = lrot,
				is_main_light = lmainlight,
				is_vertex_light = lvertexlight,
				brightness = l_brightness,
				frustum = {
					size = l_frustum_size,
					near = l_frustum_near,
					far = l_frustum_far
				}
			})
		end
	end
end

api.get_node = function(node_key)
	return dfp_graph.get_node(dfp_state.render_graph, node_key)
end

api.get_camera = function(ix)
	return dfp_state.cameras[ix+1]
end

api.get_light = function(ix)
	return dfp_state.lights[ix+1]
end

api.get_light_count = function()
	return #dfp_state.lights
end

api.get_camera_count = function()
	return #dfp_state.cameras
end

api.set_camera_exposure = function(l, exposure)
	local c_url = msg.url(nil, l, "dfp_camera")
	go.set(c_url, dfp_constants.PROPERTY_CAMERA_EXPOSURE, exposure)
end

api.get_camera_exposure = function(l)
	local c_url = msg.url(nil, l, "dfp_camera")
	return go.get(c_url, dfp_constants.PROPERTY_CAMERA_EXPOSURE)
end

api.set_light_brightness = function(l, brightness)
	local l_url = msg.url(nil, l, "dfp_light")
	go.set(l_url, dfp_constants.PROPERTY_LIGHT_BRIGHTNESS, brightness)
end

api.get_light_brightness = function(l)
	local l_url = msg.url(nil, l, "dfp_light")
	return go.get(l_url, dfp_constants.PROPERTY_LIGHT_BRIGHTNESS)
end

api.on_reload = function()
	dfp_state.config_dirty = true
end

api.get_config_default = function()
	return dfp_config.default()
end

api.get_config = function()
	return dfp_state.config
end

-- This must be called from a render script
api.render = function()
	if not dfp_state.render_init then
		init_render()
	end

	if dfp_state.config_dirty then
		dfp_state:rebuild()
		dfp_state.config_dirty = false
	end

	dfp_state:resize()
	dfp_state:render()
end

return api