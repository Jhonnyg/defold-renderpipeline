
local dfp_graph          = require 'dfp.core.graph'
local dfp_shadows        = require 'dfp.core.shadows'
local dfp_lighting       = require 'dfp.core.lighting'
local dfp_lighting_hdr   = require 'dfp.core.passes.lighting_hdr'
local dfp_postprocessing = require 'dfp.core.postprocessing'
local dfp_constants      = require 'dfp.core.constants'
local dfp_config         = require 'dfp.core.config'
local dfp_helpers        = require 'dfp.core.helpers'
local dfp_pass           = require 'dfp.core.pass'

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

dfp_state.rebuild = function(self)
	local function do_target(buffer, x, y, create_fn, conditions_met)
		if conditions_met then
			if dfp_state.render_targets[buffer] == nil then
				print("Creating RT " .. buffer)
				dfp_state.render_targets[buffer] = create_fn(x, y, dfp_state.config)
			end
		else
			if dfp_state.render_targets[buffer] ~= nil then
				print("Deleting RT " .. buffer)
				render.delete_render_target(dfp_state.render_targets[buffer])
				dfp_state.render_targets[buffer] = nil
			end
		end
	end

	local do_shadow_buffer 		   = dfp_state.config[dfp_constants.config_keys.SHADOWS]
	local do_postprocessing_buffer = dfp_state.config[dfp_constants.config_keys.POSTPROCESSING] or dfp_state.config[dfp_constants.config_keys.LIGHTING_HDR]
	local do_lighting_buffer 	   = do_postprocessing_buffer
	local do_lighting_passbuffer   = dfp_state.config[dfp_constants.config_keys.POSTPROCESSING] and dfp_state.config[dfp_constants.config_keys.POSTPROCESSING_BLOOM]
	local do_downsample_buffer     = do_lighting_passbuffer
	
	local shadow_map_size = dfp_state.config[dfp_constants.config_keys.SHADOWS_SHADOW_MAP_SIZE]
	local window_w        = render.get_window_width()
	local window_h        = render.get_window_height()
	
	do_target("shadow_buffer",         shadow_map_size, shadow_map_size, dfp_shadows.make_target,        do_shadow_buffer)
	do_target("postprocessing_buffer", window_w,        window_h,      	 dfp_postprocessing.make_target, do_postprocessing_buffer)
	do_target("lighting_buffer", 	   window_w,        window_h,        dfp_lighting.make_target,       do_lighting_buffer)
	do_target("lighting_buffer_hdr",   window_w,        window_h,        dfp_lighting.make_target_hdr,   do_lighting_buffer_hdr)

	local ds_w     = window_w
	local ds_h     = window_h
	local max_mips = 5
	for i = 1, max_mips do
		do_target("downsample_buffer_" .. i, ds_w, ds_h, dfp_postprocessing.make_target, do_downsample_buffer)
		ds_w = math.ceil(ds_w / 2)
		ds_h = math.ceil(ds_h / 2)
		if ds_w <= 1 or ds_h <= 1 then
			break
		end
	end

	self.render_passes = {}

	local function do_pass(pass, pass_fn, pass_target, pass_textures, condition)
		if condition then
			print("Creating pass " .. pass)
			local textures = {}
			if pass_textures ~= nil then
				for k, v in pairs(pass_textures) do
					textures[k] = dfp_state.render_targets[v]
				end
			end

			table.insert(self.render_passes, pass_fn(dfp_state.render_targets[pass_target], textures))
		end
	end

	local do_shadow_pass       = do_shadow_buffer
	local do_lighting_pass     = dfp_state.config[dfp_constants.config_keys.LIGHTING]
	local do_lighting_hdr_pass = do_lighting_pass and dfp_state.config[dfp_constants.config_keys.LIGHTING_HDR]
	
	do_pass(dfp_constants.node_keys.SHADOWS,      dfp_shadows.make_pass,      "shadow_buffer", nil, do_shadow_buffer)
	do_pass(dfp_constants.node_keys.LIGHTING,     dfp_lighting.make_pass,     "lighting_buffer", { [1] = "shadow_buffer" }, do_lighting_pass)
	do_pass(dfp_constants.node_keys.LIGHTING_HDR, dfp_lighting_hdr.make_pass, "lighting_buffer_hdr", { [0] = "lighting_buffer" }, do_lighting_hdr_pass)
end

dfp_state.resize = function(self)
	local function do_resize(target_name, w, h)
		local rt = dfp_state.render_targets[target_name]
		if rt ~= nil then
			local current_w = render.get_render_target_width(rt, render.BUFFER_COLOR_BIT)
			local current_h = render.get_render_target_height(rt, render.BUFFER_COLOR_BIT)
			if current_w ~= w or current_h ~= h then
				render.set_render_target_size(rt, w, h)
			end
		end
	end

	local shadow_map_size = dfp_state.config[dfp_constants.config_keys.SHADOWS_SHADOW_MAP_SIZE]
	do_resize("shadow_buffer", shadow_map_size, shadow_map_size)
	do_resize("lighting_buffer", render.get_window_width(), render.get_window_height())
	do_resize("postprocessing_buffer", render.get_window_width(), render.get_window_height())
end

dfp_state.render = function(self)
	dfp_pass.begin_frame()
	
	for k, v in pairs(self.render_data.cameras) do
		for pk, pv in pairs(self.render_passes) do
			pv.execute(pv, self.render_data, v)
		end
	end
end

--[[
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

		if dfp_state.config[dfp_constants.config_keys.LIGHTING_HDR] then
			node_lighting_hdr 			               = dfp_graph.node(dfp_lighting.pass_hdr, dfp_constants.node_keys.LIGHTING_HDR)
			node_lighting_hdr.constant_buffer          = render.constant_buffer()
			node_lighting_hdr.constant_buffer.exposure = vmath.vector4(0.5,0,0,0)
			node_lighting_hdr.predicates               = dfp_state.render_predicates.TONEMAPPING_PASS
			node_lighting_hdr.material                 = dfp_constants.material_keys.TONEMAPPING_PASS
			node_lighting_hdr.textures                 = { node_lighting.target }
			node_lighting_hdr.target                   = dfp_state.render_targets["lighting_buffer_hdr"]
		end
	end

	if dfp_state.config[dfp_constants.config_keys.POSTPROCESSING] then
		-- This creates a dummy node as a container for postprocessing effects to hook into
		node_postprocessing        = dfp_graph.node(nil, dfp_constants.node_keys.POSTPROCESSING)
		--node_postprocessing.target = dfp_state.render_targets["postprocessing_buffer"]

		if dfp_state.config[dfp_constants.config_keys.POSTPROCESSING_DOF] then
		end
		
		if dfp_state.config[dfp_constants.config_keys.POSTPROCESSING_BLOOM] then
			node_postprocessing_bloom                      = dfp_graph.node(dfp_postprocessing.pass_bloom, dfp_constants.node_keys.POSTPROCESSING_BLOOM)
			node_postprocessing_bloom.textures             = { dfp_state.render_targets["lighting_buffer_hdr"] }
			node_postprocessing_bloom.target               = render.RENDER_TARGET_DEFAULT
			node_postprocessing_bloom.constant_buffer      = render.constant_buffer()
			node_postprocessing_bloom.material             = dfp_constants.material_keys.BLOOM_PASS
			node_postprocessing_bloom.predicate            = dfp_state.render_predicates.BLOOM_PASS_DOWNSAMPLE
			-- Downsampling pass
			node_postprocessing_bloom.material_downsample  = dfp_constants.material_keys.BLOOM_PASS_DOWNSAMPLE
			node_postprocessing_bloom.predicate_downsample = dfp_state.render_predicates.BLOOM_PASS_DOWNSAMPLE
			node_postprocessing_bloom.targets_downsample   = dfp_state.render_targets["downsample_buffers"]
			-- Upsampling pass
			node_postprocessing_bloom.material_upsample    = dfp_constants.material_keys.BLOOM_PASS_UPSAMPLE
			node_postprocessing_bloom.predicate_upsample   = dfp_state.render_predicates.BLOOM_PASS_UPSAMPLE
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
				local tex_node = dfp_graph.get_node(node_root, tex_key)
				table.insert(node_custom_pass.textures, tex_node.target)
			end
		end

		local before_node = dfp_graph.get_node(node_root, desc["before"])
		local after_node = dfp_graph.get_node(node_root, desc["after"])

		if before_node ~= nil and after_node_node ~= nil then
			error("Specifying both 'before' and 'after' nodes not supported for custom passes (name: " .. desc.handle .. ")")
		end

		if before_node ~= nil then
			print("Adding custom pass " .. desc.handle .. " before " .. before_node.name)
			local before_parent = dfp_graph.get_parent(node_root, before_node.name)
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

	dfp_state.render_graph = node_root
end
--]]

local function init_render()
	for k, v in pairs(dfp_constants.material_keys) do
		dfp_state.render_predicates[k] = render.predicate({v})
	end

	dfp_state:rebuild()
	--rebuild_assets()
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

api.add_custom_pass = function(desc)
	desc.handle = "custom_pass_" .. #dfp_state.custom_passes
	table.insert(dfp_state.custom_passes, desc)
	return desc.handle
end

api.enable_pass = function(handle)
	dfp_graph.set_enabled(graph.get_node(dfp_state.render_graph, handle), true)
end

api.disable_pass = function(handle)
	dfp_graph.set_enabled(graph.get_node(dfp_state.render_graph, handle), false)
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