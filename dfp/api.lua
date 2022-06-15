
local dfp_graph     = require 'dfp.core.graph'
local dfp_shadows   = require 'dfp.core.shadows'
local dfp_lighting  = require 'dfp.core.lighting'
local dfp_constants = require 'dfp.core.constants'
local dfp_config    = require 'dfp.core.config'

local dfp_state = {
	render_init       = false,
	render_graph      = {},
	render_targets    = {},
	render_data       = { cameras = {}, lights = {} },
	render_predicates = {},
	config            = {},
	lights            = {},
	cameras           = {},
}

local function rebuild_assets()
	if dfp_state.config[dfp_constants.config_keys.SHADOWS] then
		local shadow_map_size = dfp_state.config[dfp_constants.config_keys.SHADOWS_SHADOW_MAP_SIZE]
		if dfp_state.render_targets["shadow_buffer"] == nil then
			dfp_state.render_targets["shadow_buffer"] = dfp_shadows.make_target(
				shadow_map_size, shadow_map_size)
		else
			render.set_render_target_size(dfp_state.render_targets["shadow_buffer"],
				shadow_map_size, shadow_map_size)
		end
	end
end

local function rebuild_graph()
	local node_root           = dfp_graph.node()
	local node_shadow         = dfp_graph.node()
	local node_lighting       = dfp_graph.node()
	local node_postprocessing = dfp_graph.node()

	if dfp_state.config[dfp_constants.config_keys.SHADOWS] then
		node_shadow            = dfp_graph.node(dfp_shadows.pass, "shadow pass")
		node_shadow.material   = dfp_constants.material_keys.SHADOW_PASS
		node_shadow.target     = dfp_state.render_targets["shadow_buffer"]
		node_shadow.predicates = dfp_state.render_predicates.SCENE_PASS
	end
	
	if dfp_state.config[dfp_constants.config_keys.LIGHTING] then
		node_lighting            = dfp_graph.node(dfp_lighting.pass, "lighting pass")
		node_lighting.predicates = dfp_state.render_predicates.SCENE_PASS
	end

	if dfp_state.config[dfp_constants.config_keys.POST_PROCESSING] then
		node_postprocessing = dfp_graph.node(post_processing_pass, "postprocessing pass")
	end

	dfp_graph.set_output(node_root, node_shadow)
	dfp_graph.set_output(node_shadow, node_lighting)
	dfp_graph.set_output(node_lighting, node_postprocessing)

	dfp_state.render_graph = node_root
end

local function init_render()
	dfp_state.config = dfp_config.default()

	for k, v in pairs(dfp_constants.material_keys) do
		dfp_state.render_predicates[k] = render.predicate({v})
	end
	
	rebuild_assets()
	rebuild_graph()
	dfp_state.render_init = true
end

--------------
local api = {}

api.config = dfp_constants.config_keys

api.__register_light = function(cmp)
	table.insert(dfp_state.lights, cmp)
end

api.__register_camera = function(cmp)
	table.insert(dfp_state.cameras, cmp)
end

api.configure = function(tbl)
	for k, v in pairs(tbl) do
		if dfp_state.config[k] ~= nil then
			dfp_state.config[k] = v
		end
	end

	rebuild_assets()
	rebuild_graph()
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
		local c_near     = go.get(c_url, dfp_constants.PROPERTY_CAMERA_NEAR)
		local c_far      = go.get(c_url, dfp_constants.PROPERTY_CAMERA_FAR)
		local c_viewport = go.get(c_url, dfp_constants.PROPERTY_CAMERA_VIEWPORT)
		local c_clear    = go.get(c_url, dfp_constants.PROPERTY_CAMERA_CLEAR)
		local c_clear_c  = go.get(c_url, dfp_constants.PROPERTY_CAMERA_CLEAR_COLOR)
		local c_clear_d  = go.get(c_url, dfp_constants.PROPERTY_CAMERA_CLEAR_DEPTH)
		local c_clear_s  = go.get(c_url, dfp_constants.PROPERTY_CAMERA_CLEAR_STENCIL)
		local c_eye      = vmath.vector3(0, 0, 100)
		local c_look_at  = vmath.vector3(0, 0, 0)
		local c_up       = vmath.vector3(0, 1, 0)

		c.viewport      = c_viewport
		c.clear         = c_clear
		c.clear_color   = c_clear_c
		c.clear_depth   = c_clear_d
		c.clear_stencil = c_clear_s
		c.fov           = c_fov
		c.near          = c_near
		c.far           = c_far
		c.view          = vmath.matrix4_look_at(c_eye, c_look_at, c_up)
		c.projection    = vmath.matrix4()

		table.insert(dfp_state.render_data.cameras, c)
	end

	if dfp_state.config[dfp_constants.config_keys.LIGHTING] then
		for k, v in pairs(dfp_state.lights) do
			local lpos          = go.get_position(v)
			local lrot          = go.get_rotation(v)
			local lmainlighturl = msg.url(nil, v, "dfp_light")
			local lmainlight    = go.get(lmainlighturl, dfp_constants.PROPERTY_MAIN_LIGHT)
			local lvertexlight  = go.get(lmainlighturl, dfp_constants.PROPERTY_VERTEX_LIGHT)
			table.insert(dfp_state.render_data.lights, {
				position = lpos,
				rotation = lrot,
				is_main_light = lmainlight,
				is_vertex_light = lvertexlight
			})
		end
	end
end


-- This must be called from a render script
api.render = function()
	if not dfp_state.render_init then
		init_render()
	end

	-- todo: we shouldn't do all passes for all cameras as 
	--       the shadow map(s) are not based on cameras but on lights
	for k, v in pairs(dfp_state.render_data.cameras) do
		dfp_graph.execute(dfp_state.render_graph, dfp_state.render_data, v)
	end
end

return api