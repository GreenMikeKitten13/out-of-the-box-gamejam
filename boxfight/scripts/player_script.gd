extends CharacterBody3D

#class_name position_state

#var X
#var Y
#var Z

const position_code = 1

var is_local = false

var movement_speed = 10
var jump_strength = 10
var jump_timer = 0.75
var jumping = false
var can_jump = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var mouse_change = Vector2.ZERO
var mouse_sensetivity = 0.01
var distance_traveled_since_last_chunk_build = 17
var air_time = 0
var gravity_strength = 2

@onready var camera_pivot: Node3D = $"camera pivot"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	air_time = 0
	set_physics_process(false)  # ADD THIS
	set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if build_client.session.user_id == self.name:
		camera_pivot.get_node("Camera3D").current = true
	else:
		camera_pivot.get_node("Camera3D").current = false

func _input(event: InputEvent) -> void:
	if build_client.session.user_id != self.name:
		return
	if event is InputEventMouseMotion:
		mouse_change = event.relative
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	if build_client.session.user_id != self.name:
		return
	camera_pivot.rotate(Vector3.LEFT, mouse_change.y * mouse_sensetivity)
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)
	self.rotate(Vector3.DOWN, mouse_change.x * mouse_sensetivity)
	mouse_change = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if build_client.session.user_id != self.name:
		return
	var motion = Vector3.ZERO
	
	if Input.get_action_strength("forward"):
		motion += -global_transform.basis.z * movement_speed
	if Input.get_action_strength("backward"):
		motion += global_transform.basis.z * movement_speed
	if Input.get_action_strength("left"):
		motion += -global_transform.basis.x * movement_speed
	if Input.get_action_strength("right"):
		motion += global_transform.basis.x * movement_speed
	if can_jump and not jumping and Input.get_action_strength("jump"):
		jumping = true
		jump_timer = 0.25
		can_jump = false
	
	if jumping and jump_timer > 0:
		jump_timer -=  delta
		motion.y +=  (jump_timer+jump_strength) * 2
	elif jump_timer <= 0:
		jumping = false
	
	if !self.is_on_floor() and not jumping:
		can_jump= false
		air_time += delta
		motion.y -= gravity * air_time * gravity_strength
	elif self.is_on_floor():
			air_time = 0
			if not jumping:
				can_jump = true
	
	self.velocity = motion
	self.move_and_slide()

func _on_pos_send_timer_timeout() -> void:
	if build_client.session.user_id != self.name:
		return
	var state = {
		"X": position.x,
		"Y": position.y,
		"Z": position.z
	}
	while not build_client.globby_id:
		await get_tree().process_frame
	await build_client.socket.send_match_state_async(build_client.globby_id, position_code, JSON.stringify(state))
