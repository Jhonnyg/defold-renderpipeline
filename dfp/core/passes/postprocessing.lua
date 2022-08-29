local dfp_helpers   = require 'dfp.core.helpers'
local dfp_constants = require 'dfp.core.constants'
local dfp_pass      = require 'dfp.core.pass'
local dfp_log       = require 'dfp.core.log'

local bloom = {}

bloom.dispose = function(pass)
	pprint("DISPOSE")
	
	for k, v in pairs(pass.downsample_passes) do
		dfp_log("Disposing pass " .. v.pass_key, {indent = 4})
		dfp_pass.dispose_target(v.target)
	end

	dfp_log("Disposing pass " .. pass.pass_key, {indent = 2})
	dfp_pass.dispose_target(pass.target)
end

bloom.resize = function(pass)
end

bloom.execute = function(pass, render_data, camera)
	--[[
	for k, v in pairs(pass.downsample_passes) do
		v.constant_buffer.tex_resolution = vmath.vector4(v.input_width, v.input_height, 0, 0)
		dfp_pass.execute(v)
	end
	--]]

	local bloom_radius                        = render_data.postprocessing_bloom.filter_radius
	local bloom_strength                      = render_data.postprocessing_bloom.strength
	pass.output_pass.constants.u_bloom_params = vmath.vector4(bloom_radius, bloom_strength, 0, 0)
	dfp_pass.execute(pass.output_pass, true)
end

bloom.make_pass = function(state, postprocess_target)

	dfp_log("Creating pass postprocessing bloom", {indent = 2})
	
	local pass                = dfp_pass.default(dfp_constants.pass_keys.POSTPROCESSING_BLOOM)
	pass.execute              = bloom.execute
	pass.dispose              = bloom.dispose
	pass.resize               = bloom.resize
	pass.downsample_passes    = {}
	pass.upsample_passes      = {}
	pass.constant_buffer      = render.constant_buffer()
	pass.downsample_predicate = render.predicate({dfp_constants.material_keys.BLOOM_PASS_DOWNSAMPLE})
	
	local downsample_input_texture   = postprocess_target.textures[1]
	local downsample_input_texture_w = render.get_render_target_width(downsample_input_texture, render.BUFFER_COLOR_BIT)
	local downsample_input_texture_h = render.get_render_target_height(downsample_input_texture, render.BUFFER_COLOR_BIT)

	--[[
	local ds_w     = render.get_window_width()
	local ds_h     = render.get_window_height()
	local max_mips = 5
	for i = 1, max_mips do
		local ds_pass_key    = dfp_constants.pass_keys.POSTPROCESSING_BLOOM .. ".downsample[" .. i .."]"
		local ds_buffers     = {[render.BUFFER_COLOR_BIT] = { format = render.FORMAT_RGBA}}
		local ds_pass        = dfp_pass.default(ds_pass_key)

		dfp_log("Creating pass " .. ds_pass_key, { indent = 4 })

		ds_pass.targat    = dfp_pass.make_target(ds_w, ds_h, ds_buffers)
		ds_pass.predicate = pass.downsample_predicate
		ds_pass.constants = pass.constant_buffer
		ds_pass.material  = dfp_constants.material_keys.BLOOM_PASS_DOWNSAMPLE
		ds_pass.textures  = {[0] = downsample_input_texture}
		ds_pass.viewport  = vmath.vector4(0, 0, ds_w, ds_h)

		ds_pass.pipeline.clear 	     = true
		ds_pass.pipeline.clear_table = {[render.BUFFER_COLOR_BIT] = vmath.vector4()}
		ds_pass.input_width    = downsample_input_texture_w
		ds_pass.input_height   = downsample_input_texture_h 
		
		ds_w = math.ceil(ds_w / 2)
		ds_h = math.ceil(ds_h / 2)

		downsample_input_texture   = ds_pass.targat
		downsample_input_texture_w = rt_w
		downsample_input_texture_h = rt_h

		table.insert(pass.downsample_passes, ds_pass)
	end
	--]]

	-- Create output pass that blends bloom with lighting buffer --
	local output_pass_key = dfp_constants.pass_keys.POSTPROCESSING_BLOOM .. ".output"
	local output_pass     = dfp_pass.default(output_pass_key)
	output_pass.viewport  = vmath.vector4(0, 0, render.get_window_width(), render.get_window_height())
	output_pass.material  = dfp_constants.material_keys.BLOOM_PASS
	output_pass.textures  = {[0] = downsample_input_texture}
	output_pass.constants = pass.constant_buffer
	output_pass.predicate = render.predicate({dfp_constants.pass_keys.BLOOM_PASS})
	pass.output_pass      = output_pass

	output_pass.pipeline.clear 	     = true
	output_pass.pipeline.clear_table = {[render.BUFFER_COLOR_BIT] = vmath.vector4()}

	dfp_log("Creating pass " .. output_pass_key, {indent = 4})

	state:register_render_pass(pass)
end

local dof = {}
dof.make_pass = function(state)
end

dof.execute = function(pass, render_data, camera)
	for k, v in pairs(pass.downsample_passes) do
		
	end
end

local postprocessing = {}

postprocessing.make_pass = function(state)
	if not state.config[dfp_constants.config_keys.POSTPROCESSING] then
		return
	end

	dfp_log("Creating pass postprocessing")

	local texture = nil
	if state.config[dfp_constants.config_keys.LIGHTING_HDR] then
		texture = state:get_render_pass(dfp_constants.pass_keys.LIGHTING_HDR).target
	else
		texture = state:get_render_pass(dfp_constants.pass_keys.LIGHTING).target
	end

	pp_pass          = dfp_pass.default(dfp_constants.pass_keys.POSTPROCESSING)
	pp_pass.execute  = function() end
	pp_pass.textures = {texture}

	state:register_render_pass(pp_pass)
	
	-- BLOOM PASS --
	if state.config[dfp_constants.config_keys.POSTPROCESSING_BLOOM] then
		bloom.make_pass(state, pp_pass)
	end

	--[[
	-- DOF PASS --
	if state.config[dfp_constants.config_keys.POSTPROCESSING_DOF] then
		dof.make_pass(state, pp_pass)
	end
	--]]
end

return postprocessing

--[[
local pp = {}

pp.make_target = function(w, h, dfp_config)
	local color_fmt = render.FORMAT_RGBA
	local color_params = {
		format     = color_fmt,
		width      = w,
		height     = h,
		min_filter = render.FILTER_LINEAR,
		mag_filter = render.FILTER_LINEAR,
		u_wrap     = render.WRAP_CLAMP_TO_EDGE,
		v_wrap     = render.WRAP_CLAMP_TO_EDGE
	}
	return render.render_target({[render.BUFFER_COLOR_BIT] = color_params})
end

pp.pass = function(node, parent, render_data, camera)
	render.disable_state(render.STATE_DEPTH_TEST)
	render.disable_state(render.STATE_STENCIL_TEST)
	render.disable_state(render.STATE_BLEND)

	if node.target ~= nil then
		local rw = render.get_render_target_width(node.target, render.BUFFER_COLOR_BIT)
		local rh = render.get_render_target_height(node.target, render.BUFFER_COLOR_BIT)

		render.set_viewport(0, 0, rw, rh)
		render.set_render_target(node.target)
	else
		render.set_render_target(render.RENDER_TARGET_DEFAULT)
	end
	render.enable_material(node.material)

	if node.textures ~= nil then
		for k, v in pairs(node.textures) do
			render.enable_texture(k - 1, v, render.BUFFER_COLOR_BIT)
		end
	end

	render.clear({[render.BUFFER_COLOR_BIT] = vmath.vector4(0,0,0,0)})
	render.draw(node.predicate)

	if node.textures ~= nil then
		for k, v in pairs(node.textures) do
			render.disable_texture(k - 1)
		end
	end
	
	render.disable_material()

	if node.target ~= nil then
		render.set_render_target(render.RENDER_TARGET_DEFAULT)
	end
end

pp.pass_bloom = function(node, parent, render_data, camera)
	local bloom_radius                  = render_data.postprocessing_bloom.filter_radius
	local bloom_strength                = render_data.postprocessing_bloom.strength
	node.constant_buffer.u_bloom_params = vmath.vector4(bloom_radius, bloom_strength, 0, 0)
	
	render.disable_state(render.STATE_DEPTH_TEST)
	render.disable_state(render.STATE_STENCIL_TEST)
	render.disable_state(render.STATE_BLEND)

	local downsample_input_texture   = node.textures[1]
	local downsample_input_texture_w = render.get_render_target_width(downsample_input_texture, render.BUFFER_COLOR_BIT)
	local downsample_input_texture_h = render.get_render_target_height(downsample_input_texture, render.BUFFER_COLOR_BIT)

	render.enable_material(node.material_downsample)
	
	-- downsample target x times
	for k, v in pairs(node.targets_downsample) do
		local rt_w = render.get_render_target_width(v, render.BUFFER_COLOR_BIT)
		local rt_h = render.get_render_target_height(v, render.BUFFER_COLOR_BIT)

		node.constant_buffer.tex_resolution = vmath.vector4(downsample_input_texture_w, downsample_input_texture_h, 0, 0)
		
		render.set_viewport(0, 0, rt_w, rt_h)
		render.set_render_target(v)
		render.clear({[render.BUFFER_COLOR_BIT] = vmath.vector4(0,0,0,0)})
		render.enable_texture(0, downsample_input_texture, render.BUFFER_COLOR_BIT)
		render.draw(node.predicate_downsample, {constants = node.constant_buffer})
		render.disable_texture(0)
		render.set_render_target(render.RENDER_TARGET_DEFAULT)

		downsample_input_texture = v
		downsample_input_texture_w = rt_w
		downsample_input_texture_h = rt_h
	end

	-- render.disable_material()


	render.enable_material(node.material_upsample)

	-- Enable additive blending
	render.enable_state(render.STATE_BLEND)
	render.set_blend_func(render.BLEND_ONE, render.BLEND_ONE)
	
	local upsample_input_texture = downsample_input_texture
	
	for i = #node.targets_downsample-1, 1, -1 do

		local rt = node.targets_downsample[i]
		local rt_w = render.get_render_target_width(rt, render.BUFFER_COLOR_BIT)
		local rt_h = render.get_render_target_height(rt, render.BUFFER_COLOR_BIT)
		
		render.set_viewport(0, 0, rt_w, rt_h)
		render.set_render_target(rt)
		render.clear({[render.BUFFER_COLOR_BIT] = vmath.vector4(0,0,0,0)})
		render.enable_texture(0, upsample_input_texture, render.BUFFER_COLOR_BIT)
		render.draw(node.predicate_upsample, {constants = node.constant_buffer})
		render.disable_texture(0)
		render.set_render_target(render.RENDER_TARGET_DEFAULT)

		upsample_input_texture = rt
	end

	render.disable_material()

	-- draw and apply bloom filter
	render.set_render_target(node.target)

	-- TODO: this should be passed in via 'camera' argument or something similar
	local viewport_w = render.get_window_width()
	local viewport_h = render.get_window_height()

	if node.target then
		viewport_w = render.get_render_target_height(node.target, render.BUFFER_COLOR_BIT)
		viewport_h = render.get_render_target_height(node.target, render.BUFFER_COLOR_BIT)
	end

	render.set_viewport(0, 0, viewport_w, viewport_h)	
	render.enable_material(node.material)
	render.enable_texture(0, upsample_input_texture, render.BUFFER_COLOR_BIT)

	for k, v in pairs(node.textures) do
		render.enable_texture(k, v, render.BUFFER_COLOR_BIT)
	end

	render.draw(node.predicate, {constants = node.constant_buffer})
	render.disable_texture(0)
	for k, v in pairs(node.textures) do
		render.disable_texture(k)
	end
	render.disable_material()
	render.set_render_target(render.RENDER_TARGET_DEFAULT)
end

pp.pass_dof = function(node, parent, render_data, camera)
end

return pp
--]]