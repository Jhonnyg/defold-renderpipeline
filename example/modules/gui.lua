local dfp = require 'dfp.api'

local M = {}

M.init = function()
	imgui.set_style_window_rounding(6)
	imgui.set_style_frame_rounding(3)
	imgui.set_style_scrollbar_rounding(10)
	imgui.scale_all_sizes(2)
end

local function do_configure_checkbox(config, label, key)
	local changed, v = imgui.checkbox(label, config[key])
	if changed then
		config[key] = v
		dfp.configure(config)
	end
end

local function do_configure_slider(config, label, key, start, stop)
	local changed, v = imgui.slider_float(label, config[key], start, stop, 3)
	if changed then
		config[key] = v
		dfp.configure(config)
	end
end

local function do_lights()
	for i = 0, dfp.get_light_count()-1 do
		imgui.text("Light " .. i)	
		local light      = dfp.get_light(i)	
		local brightness = dfp.get_light_brightness(light)
		local changed, v = imgui.slider_float("Brightness", brightness, 0, 100, 3)
		if changed then
			dfp.set_light_brightness(light, v)
		end
	end
end

M.on_begin = function()
	local config = dfp.get_config()
	local config_dirty = false
	
	imgui.begin_window("Settings", nil, imgui.WINDOWFLAGS_MENUBAR)

	do_configure_checkbox(config, "Shadow", dfp.config.SHADOWS)
	do_configure_checkbox(config, "Lighting", dfp.config.LIGHTING)
	do_configure_checkbox(config, "Lighting - HDR", dfp.config.LIGHTING_HDR)
	do_configure_checkbox(config, "Post Processing", dfp.config.POST_PROCESSING)
	do_configure_checkbox(config, "Post Processing - Bloom", dfp.config.POST_PROCESSING_BLOOM)

	do_configure_slider(config, "Bloom Radius", dfp.config.POST_PROCESSING_BLOOM_RADIUS, 0, 0.1)
	do_configure_slider(config, "Bloom Strength", dfp.config.POST_PROCESSING_BLOOM_STRENGTH, 0, 1)

	do_lights()
end

M.on_end = function()
	imgui.end_window()
end

return M