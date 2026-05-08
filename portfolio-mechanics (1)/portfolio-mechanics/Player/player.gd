extends CharacterBody3D

############################################################
# PLAYER SCRIPT
#
# Controls:
# - First-person movement
# - Mouse/controller look
# - Health, healing and death
# - Stamina and sprinting
# - Jump animation start + airborne loop
# - Shooting with raycast damage
# - Recoil and camera shake
# - Dash ability
# - Ultimate ability
# - Player level scaling
# - Animation state switching
# - Optional gun/root follow
#
# Animation rules:
# - Grounded + no input = Animations/rifle_idle
# - Grounded + moving = Animations/rifle_run
# - Grounded + sprinting = Animations/rifle_run, faster
# - Jump pressed = Animations/rifle_jump once
# - Still airborne = Animations/rifle_jump_loop
# - Landed = immediately chooses idle or run
############################################################


############################################################
# NODE REFERENCES
############################################################

@export var camera: Camera3D
@export var visual_root: Node3D
@export var animation_player: AnimationPlayer
@export var bullet_ray: RayCast3D
@export var gun_root: Node3D


############################################################
# HEALTH
############################################################

@export var base_max_health: float = 100.0
@export var max_health: float = 100.0
var health: float = 100.0

@export var heal_delay: float = 3.0
@export var heal_rate: float = 5.0
var time_since_damage: float = 0.0


############################################################
# MOVEMENT
############################################################

@export var base_walk_speed: float = 7.0
@export var base_sprint_speed: float = 11.0
@export var base_jump_velocity: float = 5.0

@export var walk_speed: float = 7.0
@export var sprint_speed: float = 11.0
@export var jump_velocity: float = 5.0

var is_sprinting: bool = false
var movement_input_strength: float = 0.0


############################################################
# STAMINA
############################################################

@export var base_max_stamina: float = 100.0
@export var max_stamina: float = 100.0
var stamina: float = 100.0

@export var stamina_drain_speed: float = 30.0
@export var stamina_recovery_speed: float = 22.0


############################################################
# PLAYER PROGRESSION
############################################################

var player_level: int = 1

@export var health_gain_per_level: float = 5.0
@export var stamina_gain_per_level: float = 3.0
@export var speed_gain_per_level: float = 0.15
@export var weapon_damage_gain_per_level: int = 2


############################################################
# CAMERA / LOOK
############################################################

var rotation_x: float = 0.0
var rotation_y: float = 0.0

var is_aiming: bool = false

@export var normal_fov: float = 85.0
@export var aim_fov: float = 60.0

@export var normal_mouse_sensitivity: float = 0.2
@export var aim_mouse_sensitivity: float = 0.12

@export var normal_controller_sensitivity: float = 1.0
@export var aim_controller_sensitivity: float = 0.55

@export var controller_deadzone: float = 0.18


############################################################
# FIRST-PERSON CAMERA POSITION
#
# If the camera clips into the player, try changing Z:
# -0.55  OR  0.55
############################################################

@export var first_person_camera_position: Vector3 = Vector3(0.0, 1.55, -0.55)
@export var camera_position_lerp_speed: float = 25.0
@export var camera_near_clip: float = 0.01


############################################################
# CAMERA EFFECTS
############################################################

@export var camera_shake_recovery: float = 8.0
var camera_shake_strength: float = 0.0

var ui_recoil_kick: float = 0.0
var ui_jump_kick: float = 0.0


############################################################
# GUN FOLLOW
#
# Best setup:
# Camera3D
# └── GunRoot
#     └── GunModel
############################################################

@export var gun_follow_enabled: bool = true
@export var gun_follow_camera_speed: float = 18.0


############################################################
# SHOOTING
############################################################

@export var base_weapon_damage: int = 45
@export var weapon_damage: int = 45
@export var fire_rate: float = 0.22

var can_shoot: bool = true
var is_firing: bool = false


############################################################
# RECOIL
############################################################

@export var recoil_strength: float = 3.0
@export var recoil_recovery: float = 12.0
var recoil: float = 0.0


############################################################
# DASH
############################################################

@export var dash_distance: float = 10.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 4.0
@export var dash_fov_bonus: float = 12.0

var dash_speed: float = 55.0
var can_dash: bool = true
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO


############################################################
# ULTIMATE
############################################################

@export var ultimate_damage: int = 60
@export var ultimate_range: float = 18.0
@export var ultimate_knockback: float = 18.0
@export var ultimate_cooldown: float = 90.0
@export var ultimate_camera_shake: float = 0.85

var can_use_ultimate: bool = true


############################################################
# ANIMATIONS
#
# These names match your AnimationPlayer dropdown exactly.
############################################################

@export var idle_animation: String = "Animations/rifle_idle"
@export var run_animation: String = "Animations/rifle_run"
@export var jump_up_animation: String = "Animations/rifle_jump"
@export var jump_loop_animation: String = "Animations/rifle_jump_loop"

@export var shoot_animation: String = ""
@export var reload_animation: String = ""

@export var animation_blend_time: float = 0.12

@export var idle_animation_speed: float = 1.0
@export var run_animation_speed: float = 1.0
@export var sprint_animation_speed: float = 1.35
@export var jump_animation_speed: float = 1.0

var current_animation: String = ""
var jump_up_started: bool = false
var jump_up_finished: bool = false


############################################################
# READY
############################################################

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if camera == null and has_node("Camera3D"):
		camera = $Camera3D

	if visual_root == null and has_node("VisualRoot"):
		visual_root = $VisualRoot

	if bullet_ray == null and has_node("Camera3D/BulletRay"):
		bullet_ray = $Camera3D/BulletRay

	if camera != null:
		camera.near = camera_near_clip
		camera.position = first_person_camera_position

	health = max_health
	stamina = max_stamina

	apply_player_level_scaling()

	call_deferred("force_play_animation", idle_animation, idle_animation_speed)


############################################################
# INPUT
############################################################

func _input(event: InputEvent) -> void:
	handle_mouse_look(event)

	if event.is_action_pressed("shoot"):
		is_firing = true

	if event.is_action_released("shoot"):
		is_firing = false

	if event.is_action_pressed("aim"):
		is_aiming = true

	if event.is_action_released("aim"):
		is_aiming = false

	if event.is_action_pressed("teleport"):
		start_dash()

	if event.is_action_pressed("ultimate"):
		use_ultimate()


############################################################
# PROCESS
############################################################

func _process(delta: float) -> void:
	handle_controller_look(delta)
	handle_health_regeneration(delta)
	handle_camera_effects(delta)
	update_camera(delta)
	update_gun_follow(delta)

	if is_firing:
		shoot()


############################################################
# PHYSICS PROCESS
#
# Animation runs after move_and_slide(), so landing is detected.
############################################################

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	handle_jump()
	handle_dash(delta)
	handle_regular_movement(delta)

	move_and_slide()

	handle_animation()


############################################################
# MOUSE LOOK
############################################################

func handle_mouse_look(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return

	var sensitivity: float = normal_mouse_sensitivity

	if is_aiming:
		sensitivity = aim_mouse_sensitivity

	rotation_y -= event.relative.x * sensitivity
	rotation_x -= event.relative.y * sensitivity

	rotation_x = clamp(rotation_x, -80.0, 80.0)

	rotation_degrees.y = rotation_y

	if camera != null:
		camera.rotation_degrees.x = rotation_x + recoil


############################################################
# CONTROLLER LOOK
############################################################

func handle_controller_look(_delta: float) -> void:
	var sensitivity: float = normal_controller_sensitivity

	if is_aiming:
		sensitivity = aim_controller_sensitivity

	var controller_look: Vector2 = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)

	if controller_look.length() < controller_deadzone:
		return

	rotation_y -= controller_look.x * sensitivity
	rotation_x -= controller_look.y * sensitivity

	rotation_x = clamp(rotation_x, -80.0, 80.0)

	rotation_degrees.y = rotation_y

	if camera != null:
		camera.rotation_degrees.x = rotation_x + recoil


############################################################
# GRAVITY
############################################################

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


############################################################
# JUMP
#
# Starts jump-up animation once.
############################################################

func handle_jump() -> void:
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

		ui_jump_kick = 1.0
		jump_up_started = true
		jump_up_finished = false

		force_play_animation(jump_up_animation, jump_animation_speed)


############################################################
# MOVEMENT INPUT
############################################################

func get_movement_input() -> Vector2:
	var input_dir: Vector2 = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	input_dir.x += Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	input_dir.y += Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)

	if input_dir.length() < controller_deadzone:
		input_dir = Vector2.ZERO

	return input_dir.limit_length(1.0)


############################################################
# REGULAR MOVEMENT
#
# Uses input strength, not velocity, for animation choice.
############################################################

func handle_regular_movement(delta: float) -> void:
	if is_dashing:
		return

	var input_dir: Vector2 = get_movement_input()
	movement_input_strength = input_dir.length()

	var direction: Vector3 = (
		transform.basis *
		Vector3(input_dir.x, 0.0, input_dir.y)
	).normalized()

	is_sprinting = Input.is_action_pressed("sprint")

	var current_speed: float = walk_speed

	if is_sprinting and stamina > 0.0 and movement_input_strength > 0.15:
		current_speed = sprint_speed
		stamina -= stamina_drain_speed * delta
	else:
		stamina += stamina_recovery_speed * delta

	stamina = clamp(stamina, 0.0, max_stamina)

	if movement_input_strength > 0.15:
		velocity.x = direction.x * current_speed * movement_input_strength
		velocity.z = direction.z * current_speed * movement_input_strength
	else:
		movement_input_strength = 0.0
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)


############################################################
# DASH
############################################################

func start_dash() -> void:
	if not can_dash:
		return

	if camera == null:
		return

	can_dash = false
	is_dashing = true
	dash_timer = dash_duration

	dash_direction = -camera.global_transform.basis.z
	dash_direction.y = 0.0
	dash_direction = dash_direction.normalized()

	dash_speed = dash_distance / dash_duration

	await get_tree().create_timer(dash_cooldown).timeout

	can_dash = true


func handle_dash(delta: float) -> void:
	if not is_dashing:
		return

	dash_timer -= delta

	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed

	if dash_timer <= 0.0:
		is_dashing = false


############################################################
# HEALTH
############################################################

func handle_health_regeneration(delta: float) -> void:
	if health <= 0.0:
		return

	if health >= max_health:
		return

	time_since_damage += delta

	if time_since_damage >= heal_delay:
		health += heal_rate * delta
		health = clamp(health, 0.0, max_health)


func take_damage(amount: int) -> void:
	health -= float(amount)
	health = clamp(health, 0.0, max_health)

	time_since_damage = 0.0

	add_camera_shake(0.35)

	print("Player Health: ", health)

	if health <= 0.0:
		die()


func die() -> void:
	print("Player Died")
	get_tree().reload_current_scene()


############################################################
# SHOOTING
############################################################

func shoot() -> void:
	if not can_shoot:
		return

	can_shoot = false

	recoil += recoil_strength
	ui_recoil_kick = 1.0

	get_tree().call_group(
		"enemies",
		"hear_gunshot",
		global_position
	)

	if bullet_ray != null:
		bullet_ray.force_raycast_update()

		if bullet_ray.is_colliding():
			var target: Object = bullet_ray.get_collider()

			if target != null:
				print("Hit: ", target.name)

				if target.has_method("take_damage"):
					target.take_damage(weapon_damage)

	play_one_shot_animation(shoot_animation)

	await get_tree().create_timer(fire_rate).timeout

	can_shoot = true


############################################################
# ULTIMATE
############################################################

func use_ultimate() -> void:
	if not can_use_ultimate:
		return

	can_use_ultimate = false

	print("ULTIMATE ACTIVATED")

	add_camera_shake(ultimate_camera_shake)

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		if not enemy is Node3D:
			continue

		var enemy_3d: Node3D = enemy as Node3D
		var distance: float = global_position.distance_to(enemy_3d.global_position)

		if distance <= ultimate_range:
			var direction: Vector3 = enemy_3d.global_position - global_position
			direction.y = 0.0
			direction = direction.normalized()

			if enemy_3d.has_method("apply_knockback"):
				enemy_3d.apply_knockback(direction * ultimate_knockback)

			if enemy_3d.has_method("take_damage"):
				enemy_3d.take_damage(ultimate_damage)

	await get_tree().create_timer(ultimate_cooldown).timeout

	can_use_ultimate = true


############################################################
# CAMERA EFFECTS
############################################################

func handle_camera_effects(delta: float) -> void:
	if camera == null:
		return

	var target_fov: float = normal_fov

	if is_aiming:
		target_fov = aim_fov

	if is_dashing:
		target_fov += dash_fov_bonus

	camera.fov = lerp(camera.fov, target_fov, 10.0 * delta)

	recoil = lerp(recoil, 0.0, recoil_recovery * delta)

	ui_recoil_kick = lerp(ui_recoil_kick, 0.0, 8.0 * delta)
	ui_jump_kick = lerp(ui_jump_kick, 0.0, 6.0 * delta)

	camera.rotation_degrees.x = rotation_x + recoil


func add_camera_shake(amount: float) -> void:
	camera_shake_strength += amount
	camera_shake_strength = clamp(camera_shake_strength, 0.0, 1.0)


func get_camera_shake_offset(delta: float) -> Vector3:
	if camera_shake_strength <= 0.01:
		camera_shake_strength = 0.0
		return Vector3.ZERO

	var shake_offset: Vector3 = Vector3(
		randf_range(-camera_shake_strength, camera_shake_strength),
		randf_range(-camera_shake_strength, camera_shake_strength),
		0.0
	)

	camera_shake_strength = move_toward(
		camera_shake_strength,
		0.0,
		camera_shake_recovery * delta
	)

	return shake_offset


############################################################
# CAMERA POSITION
############################################################

func update_camera(delta: float) -> void:
	if camera == null:
		return

	camera.position = camera.position.lerp(
		first_person_camera_position,
		camera_position_lerp_speed * delta
	)

	camera.position += get_camera_shake_offset(delta)


############################################################
# GUN FOLLOW
############################################################

func update_gun_follow(delta: float) -> void:
	if not gun_follow_enabled:
		return

	if gun_root == null:
		return

	if camera == null:
		return

	gun_root.global_transform.basis = gun_root.global_transform.basis.slerp(
		camera.global_transform.basis,
		gun_follow_camera_speed * delta
	)


############################################################
# PLAYER LEVEL
############################################################

func set_player_level(new_level: int) -> void:
	player_level = max(new_level, 1)
	apply_player_level_scaling()

	print("Player Level: ", player_level)


func apply_player_level_scaling() -> void:
	var level_bonus: int = player_level - 1

	max_health = base_max_health + health_gain_per_level * float(level_bonus)
	max_stamina = base_max_stamina + stamina_gain_per_level * float(level_bonus)

	walk_speed = base_walk_speed + speed_gain_per_level * float(level_bonus)
	sprint_speed = base_sprint_speed + speed_gain_per_level * float(level_bonus)

	jump_velocity = base_jump_velocity

	weapon_damage = base_weapon_damage + weapon_damage_gain_per_level * level_bonus

	health = clamp(health, 0.0, max_health)
	stamina = clamp(stamina, 0.0, max_stamina)


############################################################
# ANIMATION STATE MACHINE
############################################################

func handle_animation() -> void:
	if animation_player == null:
		return

	var grounded: bool = is_on_floor()
	var moving: bool = movement_input_strength > 0.15

	# Grounded always overrides jump-loop.
	if grounded:
		jump_up_started = false
		jump_up_finished = false

		if moving:
			if is_sprinting:
				play_animation(run_animation, sprint_animation_speed)
			else:
				play_animation(run_animation, run_animation_speed)
		else:
			play_animation(idle_animation, idle_animation_speed)

		return

	# Airborne jump-up first.
	if jump_up_started and not jump_up_finished:
		if current_animation != jump_up_animation:
			force_play_animation(jump_up_animation, jump_animation_speed)
			return

		var jump_position: float = animation_player.current_animation_position
		var jump_length: float = animation_player.current_animation_length

		if jump_length > 0.0 and jump_position >= jump_length - 0.05:
			jump_up_finished = true
			play_animation(jump_loop_animation, jump_animation_speed)

		return

	# Airborne loop.
	play_animation(jump_loop_animation, jump_animation_speed)


func play_animation(animation_name: String, speed: float = 1.0) -> void:
	if animation_name == "":
		return

	if animation_player == null:
		return

	if not animation_player.has_animation(animation_name):
		print("Missing animation: ", animation_name)
		print("Available animations: ", animation_player.get_animation_list())
		return

	animation_player.speed_scale = speed

	if current_animation == animation_name:
		return

	current_animation = animation_name

	animation_player.play(
		animation_name,
		animation_blend_time
	)


func force_play_animation(animation_name: String, speed: float = 1.0) -> void:
	if animation_name == "":
		return

	if animation_player == null:
		return

	if not animation_player.has_animation(animation_name):
		print("Missing animation: ", animation_name)
		print("Available animations: ", animation_player.get_animation_list())
		return

	current_animation = animation_name
	animation_player.speed_scale = speed

	animation_player.play(
		animation_name,
		animation_blend_time
	)


func play_one_shot_animation(animation_name: String) -> void:
	if animation_name == "":
		return

	if animation_player == null:
		return

	if not animation_player.has_animation(animation_name):
		return

	animation_player.play(animation_name, animation_blend_time)
