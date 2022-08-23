local dfp = require 'dfp.api'

local M = {}

M.default = function()
	return {
		id             = 0,
		forward        = 0,
		sidestep       = 0,
		up             = 0,
		yaw            = 0,
		pitch          = 0,
		movement_speed = 20,
		rotation_speed = 0.25,
	}
end

M.move_forward = function(camera)
	camera.forward = camera.forward - camera.movement_speed
end

M.move_backward = function(camera)
	camera.forward = camera.forward + camera.movement_speed
end

M.move_up = function(camera)
	camera.up = camera.up + camera.movement_speed
end

M.move_down = function(camera)
	camera.up = camera.up - camera.movement_speed
end

M.strafe_left = function(camera)
	camera.sidestep = camera.sidestep - camera.movement_speed
end

M.strafe_right = function(camera)
	camera.sidestep = camera.sidestep + camera.movement_speed
end

M.rotate = function(camera, yaw, pitch)
	camera.yaw   = camera.yaw - yaw * camera.rotation_speed
	camera.pitch = camera.pitch + pitch * camera.rotation_speed
end

M.update = function(camera, dt)
	local main_camera 		   = dfp.get_camera(camera.id)
	local main_camera_position = go.get_world_position(main_camera)
	local forward_vec 		   = vmath.vector3(0,0,1)
	local side_vec             = vmath.vector3(1, 0, 0)
	
	local camera_yaw           = vmath.quat_rotation_y(math.rad(camera.yaw))
	local camera_pitch         = vmath.quat_rotation_x(math.rad(camera.pitch))
	local camera_rot           = camera_yaw * camera_pitch

	local forward_scaled       = camera.forward * dt
	local sidestep_scaled      = camera.sidestep * dt
	local up_scaled            = camera.up * dt

	forward_vec = vmath.rotate(camera_rot, forward_vec)
	forward_vec = forward_vec * forward_scaled

	side_vec = vmath.rotate(camera_rot, side_vec)
	side_vec = side_vec * sidestep_scaled
	local new_pos = main_camera_position + forward_vec + side_vec
	new_pos.y = new_pos.y + up_scaled

	go.set_position(new_pos, main_camera)
	go.set_rotation(camera_rot, main_camera)

	camera.forward  = 0
	camera.sidestep = 0
	camera.up       = 0
end

return M