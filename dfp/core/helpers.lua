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

local function translate_matrix(mat,pos)
	mat.m03 = mat.m03 + pos.x
	mat.m13 = mat.m13 + pos.y
	mat.m23 = mat.m23 + pos.z
	return mat
end

helpers.get_view_matrix_from_light = function(light)
	--local light_rotation_quat = helpers.get_rotation_from_yaw_pitch(light.rotation.x, light.rotation.y)

	local rotation_mat = vmath.matrix4_from_quat(light.rotation)

	return vmath.inv(translate_matrix(rotation_mat, light.position))
	
	--local translated_mat = vmath.matrix4_translation(light.position)
	--return vmath.inv(rotation_mat)
end

helpers.get_projection_matrix_from_light = function(light)
	local proj_w = light.frustum.size
	local proj_h = light.frustum.size
	local near   = light.frustum.near
	local far    = light.frustum.far
	return vmath.matrix4_orthographic(-proj_w/2, proj_w/2, -proj_h/2, proj_h/2, near, far)
end

return helpers