
local dfp_graph          = require 'dfp.core.graph'
local dfp_shadows        = require 'dfp.core.shadows'
local dfp_lighting       = require 'dfp.core.lighting'
local dfp_postprocessing = require 'dfp.core.postprocessing'
local dfp_constants      = require 'dfp.core.constants'
local dfp_config         = require 'dfp.core.config'
local dfp_helpers        = require 'dfp.core.helpers'

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

	-- This probably needs cleaning up..
	if dfp_state.config[dfp_constants.config_keys.POST_PROCESSING] or 
		dfp_state.config[dfp_constants.config_keys.LIGHTING_HDR] then

		if dfp_state.render_targets["postprocessing_buffer"] == nil then
			dfp_state.render_targets["postprocessing_buffer"] = dfp_postprocessing.make_target(
				render.get_window_width(), render.get_window_height(), dfp_state.config)
		end
			
		if dfp_state.render_targets["lighting_buffer"] == nil then
			dfp_state.render_targets["lighting_buffer"] = dfp_lighting.make_target(
				render.get_window_width(), render.get_window_height(), dfp_state.config)
		end

		if dfp_state.config[dfp_constants.config_keys.POST_PROCESSING] and dfp_state.config[dfp_constants.config_keys.POST_PROCESSING_BLOOM] then
			if dfp_state.render_targets["lighting_buffer_hdr"] == nil then
				dfp_state.render_targets["lighting_buffer_hdr"] = dfp_lighting.make_target_hdr(
				render.get_window_width(), render.get_window_height(), dfp_state.config)
			end
			
			if dfp_state.render_targets["downsample_buffers"] == nil then
				dfp_state.render_targets["downsample_buffers"] = {}

				local rt_w     = render.get_window_width()
				local rt_h     = render.get_window_height()
				local max_mips = 5

				for i = 1, max_mips do
					local downsample_rt = dfp_postprocessing.make_target(rt_w, rt_h, dfp_state.config)
					table.insert(dfp_state.render_targets["downsample_buffers"], downsample_rt)
					rt_w = math.ceil(rt_w / 2)
					rt_h = math.ceil(rt_h / 2)

					if rt_w <= 1 or rt_h <= 1 then
						break
					end
				end
			end
		end
	else
		if dfp_state.render_targets["lighting_buffer"] ~= nil then
			render.delete_render_target(dfp_state.render_targets["lighting_buffer"])
			dfp_state.render_targets["lighting_buffer"] = nil
		end

		if dfp_state.render_targets["postprocessing_buffer"] ~= nil then
			render.delete_render_target(dfp_state.render_targets["postprocessing_buffer"])
			dfp_state.render_targets["postprocessing_buffer"] = nil
		end

		if dfp_state.render_targets["downsample_buffers"] ~= nil then
			for k, v in pairs(dfp_state.render_targets["downsample_buffers"]) do
				render.delete_render_target(v)
			end
			dfp_state.render_targets["downsample_buffers"] = nil
		end

		if dfp_state.render_targets["lighting_buffer_hdr"] ~= nil then
			render.delete_render_target(dfp_state.render_targets["lighting_buffer_hdr"])
			dfp_state.render_targets["lighting_buffer_hdr"] = nil
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

	if dfp_state.render_targets["postprocessing_buffer"] ~= nil then
		resize_target_if_size_changed(dfp_state.render_targets["postprocessing_buffer"],
			render.get_window_width(), render.get_window_height())
	end
end

local function print_graph(root)
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

		lbl_flags = {}
		if not node.enabled then
			table.insert(lbl_flags, "disabled")
		end

		if #lbl_flags > 0 then
			lbl_flags_str = " (" .. table.concat(lbl_flags, "|") .. ")"
			lbl = lbl .. lbl_flags_str
		end
		
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

local function get_node_parent(root, node_key)
	if root == nil then
		return nil
	end
	local node = root
	local node_parent = nil
	repeat
		if node.name == node_key then
			return node_parent
		end
		node_parent = node
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
			node.enabled = flag
		end
	end
end

local function rebuild_graph()
	local node_root                 = dfp_graph.node(nil, dfp_constants.node_keys.ROOT)
	local node_framebuffer          = dfp_graph.node(nil, dfp_constants.node_keys.FRAMEBUFFER)
	local node_shadow               = dfp_graph.node(nil, dfp_constants.node_keys.SHADOWS)
	local node_lighting             = dfp_graph.node(nil, dfp_constants.node_keys.LIGHTING)
	local node_lighting_hdr         = dfp_graph.node(nil, dfp_constants.node_keys.LIGHTING_HDR)
	local node_postprocessing       = dfp_graph.node(nil, dfp_constants.node_keys.POSTPROCESSING)
	local node_postprocessing_bloom = dfp_graph.node(nil, dfp_constants.node_keys.POSTPROCESSING_BLOOM)

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
		node_lighting_hdr.constant_buffer.exposure = vmath.vector4(0.5,0,0,0)
		node_lighting_hdr.predicates               = dfp_state.render_predicates.TONEMAPPING_PASS
		node_lighting_hdr.material                 = dfp_constants.material_keys.TONEMAPPING_PASS
		node_lighting_hdr.textures                 = { node_lighting.target }
		node_lighting_hdr.target                   = dfp_state.render_targets["lighting_buffer_hdr"]
	end

	if dfp_state.config[dfp_constants.config_keys.POST_PROCESSING] then
		-- This creates a dummy node as a container for postprocessing effects to hook into
		node_postprocessing        = dfp_graph.node(nil, dfp_constants.node_keys.POSTPROCESSING)
		--node_postprocessing.target = dfp_state.render_targets["postprocessing_buffer"]
		
		if dfp_state.config[dfp_constants.config_keys.POST_PROCESSING_BLOOM] then
			node_postprocessing_bloom                                 = dfp_graph.node(dfp_postprocessing.pass_bloom, dfp_constants.node_keys.POSTPROCESSING_BLOOM)
			node_postprocessing_bloom.textures                        = { dfp_state.render_targets["lighting_buffer_hdr"] }
			node_postprocessing_bloom.target                          = render.RENDER_TARGET_DEFAULT
			node_postprocessing_bloom.constant_buffer                 = render.constant_buffer()
			node_postprocessing_bloom.material                        = dfp_constants.material_keys.BLOOM_PASS
			node_postprocessing_bloom.predicate                       = dfp_state.render_predicates.BLOOM_PASS_DOWNSAMPLE
			-- Downsampling pass
			node_postprocessing_bloom.material_downsample             = dfp_constants.material_keys.BLOOM_PASS_DOWNSAMPLE
			node_postprocessing_bloom.predicate_downsample            = dfp_state.render_predicates.BLOOM_PASS_DOWNSAMPLE
			node_postprocessing_bloom.targets_downsample              = dfp_state.render_targets["downsample_buffers"]
			-- Upsampling pass
			node_postprocessing_bloom.material_upsample               = dfp_constants.material_keys.BLOOM_PASS_UPSAMPLE
			node_postprocessing_bloom.predicate_upsample              = dfp_state.render_predicates.BLOOM_PASS_UPSAMPLE
		end
	end

	dfp_graph.set_output(node_root, node_shadow)
	dfp_graph.set_output(node_shadow, node_lighting)
	dfp_graph.set_output(node_lighting, node_lighting_hdr)
	dfp_graph.set_output(node_lighting_hdr, node_postprocessing)
	dfp_graph.set_output(node_postprocessing, node_postprocessing_bloom)
	dfp_graph.set_output(node_postprocessing_bloom, node_framebuffer)
	
	-- Hook up custom passes after core graph has been built
	for k, v in pairs(dfp_state.custom_passes) do
		local desc = dfp_state.custom_passes[k]
		local node_custom_pass = dfp_graph.node(dfp_postprocessing.pass, desc.handle)

		if desc["enabled"] ~= nil then
			node_custom_pass.enabled = desc["enabled"]
		end
		node_custom_pass.material = v.material
		node_custom_pass.predicate = render.predicate(v.predicate)

		if v.textures ~= nil then
			node_custom_pass.textures = {}
			for _, tex_key in pairs(v.textures) do
				local tex_node = get_node(node_root, tex_key)
				table.insert(node_custom_pass.textures, tex_node.target)
			end
		end

		local before_node = get_node(node_root, desc["before"])
		local after_node = get_node(node_root, desc["after"])

		if before_node ~= nil and after_node_node ~= nil then
			error("Specifying both 'before' and 'after' nodes not supported for custom passes (name: " .. desc.handle .. ")")
		end

		if before_node ~= nil then
			print("Adding custom pass " .. desc.handle .. " before " .. before_node.name)
			local before_parent = get_node_parent(node_root, before_node.name)
			dfp_graph.set_output(before_parent, node_custom_pass)
			dfp_graph.set_output(node_custom_pass, before_node)
		end
		
		if after_node ~= nil then
			print("Adding custom pass " .. desc.handle .. " after " .. after_node.name)
			local old_output = after_node.output
			dfp_graph.set_output(after_node, node_custom_pass)
			dfp_graph.set_output(node_custom_pass, old_output)
		end
	end

	--print_graph(node_root)

	dfp_state.render_graph = node_root
end

local function init_render()
	for k, v in pairs(dfp_constants.material_keys) do
		dfp_state.render_predicates[k] = render.predicate({v})
	end
	
	rebuild_assets()
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
		--c.view          = vmath.inv(vmath.matrix4_from_quat(c_rot) * vmath.matrix4_translation(c_pos))
		c.projection    = vmath.matrix4()

		-- todo: fix this
		c.view = vmath.inv(dfp_helpers.translate_matrix(vmath.matrix4_from_quat(c_rot), c_pos))

		table.insert(dfp_state.render_data.cameras, c)
	end

	if dfp_state.config[dfp_constants.config_keys.POST_PROCESSING_BLOOM] then
		local params = {}
		params.filter_radius = dfp_state.config[dfp_constants.config_keys.POST_PROCESSING_BLOOM_RADIUS]
		params.strength 	 = dfp_state.config[dfp_constants.config_keys.POST_PROCESSING_BLOOM_STRENGTH]
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

api.get_camera = function(ix)
	return dfp_state.cameras[ix+1]
end

api.get_light = function(ix)
	return dfp_state.lights[ix+1]
end

api.get_light_count = function()
	return #dfp_state.lights
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