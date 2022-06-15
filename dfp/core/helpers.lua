local helpers = {}

helpers.get_rotation_from_yaw_pitch = function(yaw,pitch)
	return vmath.quat_rotation_x(math.rad(pitch)) * vmath.quat_rotation_y(math.rad(yaw))
end

helpers.get_main_light = function(render_data)
	for k, v in pairs(render_data.lights) do
		if v.is_main_light then
			return v
		end
	end
end

helpers.get_view_matrix_from_light = function(light)
	local light_rotation_quat = helpers.get_rotation_from_yaw_pitch(light.rotation.x, light.rotation.y)
	return vmath.matrix4_from_quat(light_rotation_quat)
end

helpers.get_projection_matrix_from_light = function(light)
	local proj_w = light.frustum.size
	local proj_h = light.frustum.size
	local near   = light.frustum.near
	local far    = light.frustum.far
	return vmath.matrix4_orthographic(-proj_w/2, proj_w/2, -proj_h/2, proj_h/2, near, far)
end

return helpers