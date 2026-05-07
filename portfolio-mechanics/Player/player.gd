extends CharacterBody3D

#########################################
# References

@export var camera : Camera3D
@onready var bullet_ray : RayCast3D = $Camera3D/BulletRay


#########################################
# Health

@export var max_health := 100.0
var health := 100.0

@export var armour := 0.0

@export var heal_delay := 3.0
@export var heal_rate := 5.0

var time_since_damage := 0.0


#########################################
# Movement

@export var walk_speed := 7.0
@export var sprint_speed := 11.0
@export var jump_velocity := 5.0

var is_sprinting := false


#########################################
# Stamina

@export var max_stamina := 100.0
var stamina := 100.0

@export var stamina_drain_speed := 30.0
@export var stamina_recovery_speed := 22.0


#########################################
# Progression

var player_level := 1
var player_stage := 1

@export var player_stat_increase_per_level := 0.02

var base_max_health := 100.0
var base_armour := 0.0
var base_walk_speed := 7.0
var base_sprint_speed := 11.0
var base_max_stamina := 100.0
var base_weapon_damage := 45
var base_dash_distance := 10.0
var base_ultimate_damage := 60


func set_player_level(new_level: int) -> void:
	player_level = max(1, new_level)
	apply_player_level_scaling()
	print("Player Level: ", player_level)


func set_player_stage(new_stage: int) -> void:
	player_stage = max(1, new_stage)
	print("Player Stage: ", player_stage)


func apply_player_level_scaling() -> void:
	var health_percent := 1.0

	if max_health > 0:
		health_percent = health / max_health

	var multiplier = 1.0 + ((player_level - 1) * player_stat_increase_per_level)

	max_health = base_max_health * multiplier
	armour = base_armour * multiplier

	walk_speed = base_walk_speed * multiplier
	sprint_speed = base_sprint_speed * multiplier
	max_stamina = base_max_stamina * multiplier

	weapon_damage = roundi(base_weapon_damage * multiplier)
	dash_distance = base_dash_distance * multiplier
	ultimate_damage = roundi(base_ultimate_damage * multiplier)

	health = clamp(max_health * health_percent, 1.0, max_health)
	stamina = clamp(stamina, 0.0, max_stamina)


#########################################
# Camera / Aim

var rotation_x := 0.0
var rotation_y := 0.0

var is_aiming := false

@export var normal_fov := 75.0
@export var aim_fov := 55.0

@export var normal_mouse_sensitivity := 0.2
@export var aim_mouse_sensitivity := 0.12

@export var normal_controller_sensitivity := 1.0
@export var aim_controller_sensitivity := 0.55

@export var controller_deadzone := 0.18


#########################################
# Camera Effects

@export var camera_shake_recovery := 8.0
var camera_shake_strength := 0.0
var camera_start_position := Vector3.ZERO

var ui_recoil_kick := 0.0
var ui_jump_kick := 0.0


#########################################
# Shooting

@export var weapon_damage := 45
@export var fire_rate := 0.22

var can_shoot := true
var is_firing := false


#########################################
# Recoil

@export var recoil_strength := 3.0
@export var recoil_recovery := 12.0

var recoil := 0.0


#########################################
# Dash / Teleport Ability

@export var dash_distance := 10.0
@export var dash_speed := 55.0
@export var dash_duration := 0.18
@export var dash_cooldown := 4.0
@export var dash_fov_bonus := 12.0

var can_dash := true
var is_dashing := false
var dash_timer := 0.0
var dash_direction := Vector3.ZERO


#########################################
# Ultimate

@export var ultimate_damage := 60
@export var ultimate_range := 18.0
@export var ultimate_knockback := 18.0
@export var ultimate_cooldown := 90.0
@export var ultimate_camera_shake := 0.85

var can_use_ultimate := true


#########################################
# Setup

func _ready() -> void:
	if camera == null:
		camera = $Camera3D

	camera_start_position = camera.position

	base_max_health = max_health
	base_armour = armour
	base_walk_speed = walk_speed
	base_sprint_speed = sprint_speed
	base_max_stamina = max_stamina
	base_weapon_damage = weapon_damage
	base_dash_distance = dash_distance
	base_ultimate_damage = ultimate_damage

	health = max_health
	stamina = max_stamina

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


#########################################
# Input

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var current_mouse_sensitivity = normal_mouse_sensitivity

		if is_aiming:
			current_mouse_sensitivity = aim_mouse_sensitivity

		rotation_y -= event.relative.x * current_mouse_sensitivity
		rotation_x -= event.relative.y * current_mouse_sensitivity
		rotation_x = clamp(rotation_x, -90.0, 90.0)

		rotation_degrees.y = rotation_y
		camera.rotation_degrees.x = rotation_x + recoil

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


#########################################
# Main Update

func _process(delta: float) -> void:
	handle_controller_look(delta)
	handle_health_regeneration(delta)
	handle_camera_shake(delta)

	if is_firing:
		shoot()

	var target_fov = normal_fov

	if is_aiming:
		target_fov = aim_fov

	if is_dashing:
		target_fov += dash_fov_bonus

	camera.fov = lerp(camera.fov, target_fov, 10.0 * delta)

	recoil = lerp(recoil, 0.0, recoil_recovery * delta)

	ui_recoil_kick = lerp(ui_recoil_kick, 0.0, 8.0 * delta)
	ui_jump_kick = lerp(ui_jump_kick, 0.0, 6.0 * delta)

	camera.rotation_degrees.x = rotation_x + recoil


#########################################
# Controller Look

func handle_controller_look(_delta: float) -> void:
	var sensitivity = normal_controller_sensitivity

	if is_aiming:
		sensitivity = aim_controller_sensitivity

	var controller_look := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)

	if controller_look.length() < controller_deadzone:
		return

	rotation_y -= controller_look.x * sensitivity
	rotation_x -= controller_look.y * sensitivity

	rotation_x = clamp(rotation_x, -90.0, 90.0)

	rotation_degrees.y = rotation_y
	camera.rotation_degrees.x = rotation_x + recoil


#########################################
# Physics

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		ui_jump_kick = 1.0

	var input_dir := get_movement_input()

	var direction = (
		transform.basis *
		Vector3(input_dir.x, 0, input_dir.y)
	).normalized()

	handle_dash(delta)
	handle_regular_movement(delta, direction, input_dir.length())

	move_and_slide()


#########################################
# Movement Input

func get_movement_input() -> Vector2:
	var input_dir := Vector2.ZERO

	input_dir += Input.get_vector(
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


#########################################
# Regular Movement

func handle_regular_movement(delta: float, direction: Vector3, input_strength: float) -> void:
	if is_dashing:
		return

	is_sprinting = Input.is_action_pressed("sprint")

	var current_speed = walk_speed

	if is_sprinting and stamina > 0:
		current_speed = sprint_speed
		stamina -= stamina_drain_speed * delta
	else:
		stamina += stamina_recovery_speed * delta

	stamina = clamp(stamina, 0, max_stamina)

	if direction:
		velocity.x = direction.x * current_speed * input_strength
		velocity.z = direction.z * current_speed * input_strength
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)


#########################################
# Dash / Teleport

func start_dash() -> void:
	if not can_dash:
		return

	can_dash = false
	is_dashing = true
	dash_timer = dash_duration

	dash_direction = -camera.global_transform.basis.z
	dash_direction.y = 0
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

	if dash_timer <= 0:
		is_dashing = false


#########################################
# Health Regeneration

func handle_health_regeneration(delta: float) -> void:
	if health <= 0:
		return

	if health >= max_health:
		return

	time_since_damage += delta

	if time_since_damage >= heal_delay:
		health += heal_rate * delta
		health = clamp(health, 0, max_health)


#########################################
# Damage

func take_damage(amount: int) -> void:
	var final_damage = amount - armour
	final_damage = max(1, final_damage)

	health -= final_damage
	health = clamp(health, 0, max_health)

	time_since_damage = 0.0

	add_camera_shake(0.35)

	print("Player Health: ", health)

	if health <= 0:
		die()


func die() -> void:
	print("Player Died")
	get_tree().reload_current_scene()


#########################################
# Shooting

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

	bullet_ray.force_raycast_update()

	if bullet_ray.is_colliding():
		var target = bullet_ray.get_collider()

		print("Hit: ", target.name)

		if target.has_method("take_damage"):
			target.take_damage(weapon_damage)

	await get_tree().create_timer(fire_rate).timeout

	can_shoot = true


#########################################
# Camera Shake

func add_camera_shake(amount: float) -> void:
	camera_shake_strength += amount
	camera_shake_strength = clamp(camera_shake_strength, 0.0, 1.0)


func handle_camera_shake(delta: float) -> void:
	if camera_shake_strength <= 0.01:
		camera_shake_strength = 0.0
		camera.position = camera.position.lerp(
			camera_start_position,
			10.0 * delta
		)
		return

	var shake_offset = Vector3(
		randf_range(-camera_shake_strength, camera_shake_strength),
		randf_range(-camera_shake_strength, camera_shake_strength),
		0
	)

	camera.position = camera_start_position + shake_offset

	camera_shake_strength = move_toward(
		camera_shake_strength,
		0.0,
		camera_shake_recovery * delta
	)


#########################################
# Ultimate

func use_ultimate() -> void:
	if not can_use_ultimate:
		return

	can_use_ultimate = false

	print("ULTIMATE ACTIVATED")

	add_camera_shake(ultimate_camera_shake)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var distance = global_position.distance_to(enemy.global_position)

		if distance <= ultimate_range:
			var direction = enemy.global_position - global_position
			direction.y = 0
			direction = direction.normalized()

			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(direction * ultimate_knockback)

			if enemy.has_method("take_damage"):
				enemy.take_damage(ultimate_damage)

	await get_tree().create_timer(ultimate_cooldown).timeout

	can_use_ultimate = true
