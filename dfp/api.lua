
local dfp_graph          = require 'dfp.core.graph'
local dfp_shadows        = require 'dfp.core.shadows'
local dfp_lighting       = require 'dfp.core.lighting'
local dfp_postprocessing = require 'dfp.core.postprocessing'
local dfp_constants      = require 'dfp.core.constants'
local dfp_config         = require 'dfp.core.config'

local dfp_state = {
	render_init       = false,
	render_graph      = {},
	render_targets    = {},
	render_data       = { cameras = {}, lights = {} },
	render_predicates = {},
	custom_passes     = {},
	config            = dfp_config.default(),
	lights            = {},
	cameras           = {},
}

local function rebuild_assets()
	if dfp_state.config[dfp_constants.config_keys.SHADOWS] then
		local shadow_map_size = dfp_state.config[dfp_constants.config_keys.SHADOWS_SHADOW_MAP_SIZE]
		if dfp_state.render_targets["shadow_buffer"] == nil then
			dfp_state.render_targets["shadow_buffer"] = dfp_shadows.make_target(
				shadow_map_size, shadow_map_size, dfp_state.config)
		end
	else
		if dfp_state.render_targets["shadow_buffer"] ~= nil then
			render.delete_render_target(dfp_state.render_targets["shadow_buffer"])
		end
	end

	if dfp_state.config[dfp_constants.config_keys.POST_PROCESSING] or 
	   dfp_state.config[dfp_constants.config_keys.LIGHTING_HDR] then
		if dfp_state.render_targets["lighting_buffer"] == nil then
			dfp_state.render_targets["lighting_buffer"] = dfp_lighting.make_target(
				render.get_window_width(), render.get_window_height(), dfp_state.config)
		end
	else
		if dfp_state.render_targets["lighting_buffer"] ~= nil then
			render.delete_render_target(dfp_state.render_targets["lighting_buffer"])
		end
	end
end

local function resize_target_if_size_changed(target, w, h)
	local current_w = render.get_render_target_width(target, render.BUFFER_COLOR_BIT)
	local current_h = render.get_render_target_height(target, render.BUFFER_COLOR_BIT)
	if current_w ~= w or current_h ~= h then
		render.set_render_target_size(target, w, h)
	end
end

local function resize_assets()
	if dfp_state.render_targets["shadow_buffer"] ~= nil then
		local shadow_map_size = dfp_state.config[dfp_constants.config_keys.SHADOWS_SHADOW_MAP_SIZE]
		resize_target_if_size_changed(dfp_state.render_targets["shadow_buffer"],
			shadow_map_size, shadow_map_size)
	end

	if dfp_state.render_targets["lighting_buffer"] ~= nil then
		resize_target_if_size_changed(dfp_state.render_targets["lighting_buffer"],
			render.get_window_width(), render.get_window_height())
	end
end

local function print_graph(root)
	print("Printing graph")
	if root == nil then
		return nil
	end
	local node = root
	local depth = 0
	repeat
		local lbl = "|-"
		for i = 0, depth do
			lbl = " " .. lbl
		end
		lbl = lbl .. node.name
		depth = depth + 1
		print(lbl)
		node = node.output
	until node == nil
end

local function get_node(root, node_key)
	if root == nil then
		return nil
	end
	local node = root
	repeat
		if node.name == node_key then
			return node
		end
		node = node.output
	until node == nil
end

local function set_node_enabled_flag(handle, flag)
	if handle == nil then
		return
	end
	local node = get_node(dfp_state.render_graph, handle)
	if node ~= nil then
		if node.enabled ~= flag then
			print("Setting node visibility for " .. node.name .. " to " .. tostring(flag))
		end
		node.enabled = flag
	end
end

local function rebuild_graph()
	local node_root           = dfp_graph.node(nil, dfp_constants.node_keys.ROOT)
	local node_shadow         = dfp_graph.node()
	local node_lighting       = dfp_graph.node()
	local node_lighting_hdr   = dfp_graph.node()
	local node_postprocessing = dfp_graph.node()

	if dfp_state.config[dfp_constants.config_keys.SHADOWS] then
		node_shadow            = dfp_graph.node(dfp_shadows.pass, dfp_constants.node_keys.SHADOWS)
		node_shadow.target     = dfp_state.render_targets["shadow_buffer"]
		node_shadow.material   = dfp_constants.material_keys.SHADOW_PASS
		node_shadow.predicates = dfp_state.render_predicates.SCENE_PASS
	end
	
	if dfp_state.config[dfp_constants.config_keys.LIGHTING] then
		node_lighting            = dfp_graph.node(dfp_lighting.pass, dfp_constants.node_keys.LIGHTING)
		node_lighting.predicates = dfp_state.render_predicates.SCENE_PASS

		-- Construct bias matrix
		node_lighting.bias_matrix    = vmath.matrix4()
		node_lighting.bias_matrix.c0 = vmath.vector4(0.5, 0.0, 0.0, 0.0)
		node_lighting.bias_matrix.c1 = vmath.vector4(0.0, 0.5, 0.0, 0.0)
		node_lighting.bias_matrix.c2 = vmath.vector4(0.0, 0.0, 0.5, 0.0)
		node_lighting.bias_matrix.c3 = vmath.vector4(0.5, 0.5, 0.5, 1.0)

		node_lighting.constant_buffer = render.constant_buffer()
		node_lighting.shadow_buffer   = dfp_state.render_targets["shadow_buffer"]
		node_lighting.target          = dfp_state.render_targets["lighting_buffer"]
	end

	if dfp_state.config[dfp_constants.config_keys.LIGHTING_HDR] then
		node_lighting_hdr 			               = dfp_graph.node(dfp_lighting.pass_hdr, dfp_constants.node_keys.LIGHTING_HDR)
		node_lighting_hdr.constant_buffer          = render.constant_buffer()
		node_lighting_hdr.constant_buffer.exposure = vmath.vector4(1,0,0,0)
		node_lighting_hdr.predicates               = dfp_state.render_predicates.TONEMAPPING_PASS
		node_lighting_hdr.material                 = dfp_constants.material_keys.TONEMAPPING_PASS
	end

	if dfp_state.config[dfp_constants.config_keys.POST_PROCESSING] then
		node_postprocessing        = dfp_graph.node(nil, dfp_constants.node_keys.POSTPROCESSING)
		node_postprocessing.target = node_lighting.target
	end

	dfp_graph.set_output(node_root, node_shadow)
	dfp_graph.set_output(node_shadow, node_lighting)
	dfp_graph.set_output(node_lighting, node_lighting_hdr)
	dfp_graph.set_output(node_lighting_hdr, node_postprocessing)
	
	-- Hook up custom passes after core graph has been built
	for k, v in pairs(dfp_state.custom_passes) do
		local desc = dfp_state.custom_passes[k]
		local node_custom_pass = dfp_graph.node(dfp_postprocessing.pass, desc.handle)

		node_custom_pass.material = v.material
		node_custom_pass.predicate = render.predicate(v.predicate)

		if v.textures ~= nil then
			node_custom_pass.textures = {}
			for _, tex_key in pairs(v.textures) do
				local tex_node = get_node(node_root, tex_key)
				table.insert(node_custom_pass.textures, tex_node.target)
			end
		end

		local after_node = get_node(node_root, desc["after"])
		
		if after_node ~= nil then
			print("Adding custom pass " .. desc.handle .. " after " .. after_node.name)
			local old_output = after_node.output
			dfp_graph.set_output(after_node, node_custom_pass)
			dfp_graph.set_output(node_custom_pass, old_output)
		end
	end

	print_graph(node_root)

	dfp_state.render_graph = node_root
end

local function init_render()
	for k, v in pairs(dfp_constants.material_keys) do
		dfp_state.render_predicates[k] = render.predicate({v})
	end
	
	rebuild_assets()
	rebuild_graph()
	dfp_state.render_init = true
end

--------------
local api = {}

api.__register_light = function(cmp)
	table.insert(dfp_state.lights, cmp)
end

api.__register_camera = function(cmp)
	table.insert(dfp_state.cameras, cmp)
end

api.node_keys = dfp_constants.node_keys
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
		local c_near     = go.get(c_url, dfp_constants.PROPERTY_CAMERA_NEAR)
		local c_far      = go.get(c_url, dfp_constants.PROPERTY_CAMERA_FAR)
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
		c.near          = c_near
		c.far           = c_far
		c.view          = vmath.inv(vmath.matrix4_from_quat(c_rot) * vmath.matrix4_translation(c_pos)) 
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

			local l_frustum_size = go.get(lmainlighturl, dfp_constants.PROPERTY_LIGHT_FRUSTUM_SIZE)
			local l_frustum_near = go.get(lmainlighturl, dfp_constants.PROPERTY_LIGHT_FRUSTUM_NEAR)
			local l_frustum_far  = go.get(lmainlighturl, dfp_constants.PROPERTY_LIGHT_FRUSTUM_FAR)
			
			table.insert(dfp_state.render_data.lights, {
				position = lpos,
				rotation = lrot,
				is_main_light = lmainlight,
				is_vertex_light = lvertexlight,
				frustum = {
					size = l_frustum_size,
					near = l_frustum_near,
					far = l_frustum_far
				}
			})
		end
	end
end

api.add_custom_pass = function(desc)
	desc.handle = "custom_pass_" .. #dfp_state.custom_passes
	table.insert(dfp_state.custom_passes, desc)
	return desc.handle
end

api.enable_pass = function(handle)
	set_node_enabled_flag(handle, true)
end

api.disable_pass = function(handle)
	set_node_enabled_flag(handle, false)
end

api.get_node = function(node_key)
	return get_node(dfp_state.render_graph, node_key)
end

api.on_reload = function()
	dfp_state.config_dirty = true
end

-- This must be called from a render script
api.render = function()
	if not dfp_state.render_init then
		init_render()
	end

	if dfp_state.config_dirty then
		rebuild_assets()
		rebuild_graph()
		dfp_state.config_dirty = false
	end

	resize_assets()

	-- todo: we shouldn't do all passes for all cameras as 
	--       the shadow map(s) are not based on cameras but on lights
	for k, v in pairs(dfp_state.render_data.cameras) do
		dfp_graph.execute(dfp_state.render_graph, nil, dfp_state.render_data, v)
	end
end

return api