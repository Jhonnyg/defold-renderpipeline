local dfp_helpers   = require 'dfp.core.helpers'
local dfp_constants = require 'dfp.core.constants'
local dfp_pass      = require 'dfp.core.pass'
local dfp_log       = require 'dfp.core.log'

local bloom = {}

bloom.dispose = function(pass)
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
	for k, v in pairs(pass.downsample_passes) do
		v.constants.tex_resolution = vmath.vector4(v.input_width, v.input_height, 0, 0)
		dfp_pass.execute(v)
	end
	for k, v in pairs(pass.upsample_passes) do
		v.constants.tex_resolution = vmath.vector4(v.input_width, v.input_height, 0, 0)
		dfp_pass.execute(v)
	end

	local bloom_radius                        = render_data.postprocessing_bloom.filter_radius
	local bloom_strength                      = render_data.postprocessing_bloom.strength
	pass.output_pass.constants.u_bloom_params = vmath.vector4(bloom_radius, bloom_strength, 0, 0)
	dfp_pass.execute(pass.output_pass)
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
	pass.upsample_predicate   = render.predicate({dfp_constants.material_keys.BLOOM_PASS_UPSAMPLE})
	
	local downsample_input_texture   = postprocess_target.textures[1]
	local downsample_input_texture_w = render.get_render_target_width(downsample_input_texture, render.BUFFER_COLOR_BIT)
	local downsample_input_texture_h = render.get_render_target_height(downsample_input_texture, render.BUFFER_COLOR_BIT)

	local ds_w     = render.get_window_width()
	local ds_h     = render.get_window_height()
	local max_mips = 5
	for i = 1, max_mips do
		local ds_pass_key    = dfp_constants.pass_keys.POSTPROCESSING_BLOOM .. ".downsample[" .. i .."]"
		local ds_buffers     = {[render.BUFFER_COLOR_BIT] = { format = render.FORMAT_RGBA}}
		local ds_pass        = dfp_pass.default(ds_pass_key)

		dfp_log("Creating pass " .. ds_pass_key, { indent = 4 })

		ds_pass.target    = dfp_pass.make_target(ds_w, ds_h, ds_buffers)
		ds_pass.predicate = pass.downsample_predicate
		ds_pass.constants = pass.constant_buffer
		ds_pass.material  = dfp_constants.material_keys.BLOOM_PASS_DOWNSAMPLE
		ds_pass.textures  = {[0] = downsample_input_texture}
		ds_pass.viewport  = vmath.vector4(0, 0, ds_w, ds_h)

		ds_pass.pipeline.clear 	     = true
		ds_pass.pipeline.clear_table = {[render.BUFFER_COLOR_BIT] = vmath.vector4()}
		ds_pass.input_width          = downsample_input_texture_w
		ds_pass.input_height         = downsample_input_texture_h 
		
		ds_w = math.ceil(ds_w / 2)
		ds_h = math.ceil(ds_h / 2)

		downsample_input_texture   = ds_pass.target
		downsample_input_texture_w = ds_w
		downsample_input_texture_h = ds_h

		table.insert(pass.downsample_passes, ds_pass)
	end

	local upsample_input_texture = downsample_input_texture
	
	for i = #pass.downsample_passes-1, 1, -1 do
		local target         = pass.downsample_passes[i].target
		local rt_w           = render.get_render_target_width(target, render.BUFFER_COLOR_BIT)
		local rt_h           = render.get_render_target_height(target, render.BUFFER_COLOR_BIT)
		local us_pass_key    = dfp_constants.pass_keys.POSTPROCESSING_BLOOM .. ".upsample[" .. i .."]"
		local us_pass        = dfp_pass.default(us_pass_key)

		dfp_log("Creating pass " .. us_pass_key, { indent = 4 })

		us_pass.target    = target
		us_pass.viewport  = vmath.vector4(0, 0, rt_w, rt_h)
		us_pass.constants = pass.constant_buffer
		us_pass.textures  = {[0] = upsample_input_texture}
		us_pass.material  = dfp_constants.material_keys.BLOOM_PASS_UPSAMPLE
		us_pass.predicate = pass.upsample_predicate
		
		--us_pass.pipeline.clear 	   = false
		--us_pass.pipeline.clear_table = nil
		us_pass.pipeline.blend       = false
		us_pass.pipeline.blend_src   = render.BLEND_ONE
		us_pass.pipeline.blend_dst   = render.BLEND_ONE
		us_pass.input_width          = rt_w
		us_pass.input_height         = rt_h

		upsample_input_texture = target
		table.insert(pass.upsample_passes, us_pass)
	end

	-- Create output pass that blends bloom with lighting buffer --
	local output_pass_key = dfp_constants.pass_keys.POSTPROCESSING_BLOOM .. ".output"
	local output_pass     = dfp_pass.default(output_pass_key)
	output_pass.viewport  = vmath.vector4(0, 0, render.get_window_width(), render.get_window_height())
	output_pass.material  = dfp_constants.material_keys.BLOOM_PASS
	output_pass.constants = pass.constant_buffer
	output_pass.predicate = render.predicate({dfp_constants.material_keys.BLOOM_PASS})
	output_pass.textures  = {
		[0] = upsample_input_texture,
		[1] = postprocess_target.textures[1]}
	pass.output_pass      = output_pass

	output_pass.pipeline.clear 	     = true
	output_pass.pipeline.clear_table = {[render.BUFFER_COLOR_BIT] = vmath.vector4(1,0,0,1)}

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

postprocessing.has_config_values = function(config)
	local do_pp = config[dfp_constants.config_keys.POSTPROCESSING]
	local do_bloom = config[dfp_constants.config_keys.POSTPROCESSING_BLOOM]
	local do_dof = config[dfp_constants.config_keys.POSTPROCESSING_DOF]
	return do_pp and (do_bloom or do_dof)
end

postprocessing.make_pass = function(state)
	if not postprocessing.has_config_values(state.config) then
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
