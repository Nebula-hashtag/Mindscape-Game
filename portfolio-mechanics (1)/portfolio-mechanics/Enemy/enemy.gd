extends CharacterBody3D

#########################################
# Enemy Stats

@export var max_health := 100.0
var health := 100.0

@export var armour := 0.0

@export var patrol_speed := 3.0
@export var chase_speed := 5.5

@export var attack_damage := 10
@export var attack_range := 2.5
@export var attack_cooldown := 1.0

@export var detection_range := 20.0
@export var hearing_range := 40.0


#########################################
# Enemy Level

var enemy_level := 1

@export var enemy_stat_increase_per_level := 0.02

var base_max_health := 100.0
var base_armour := 0.0
var base_patrol_speed := 3.0
var base_chase_speed := 5.5
var base_attack_damage := 10


func set_enemy_level(new_level: int) -> void:
	enemy_level = max(1, new_level)
	apply_enemy_level_scaling()

	print("Enemy Level: ", enemy_level)


func apply_enemy_level_scaling() -> void:
	var multiplier = 1.0 + ((enemy_level - 1) * enemy_stat_increase_per_level)

	max_health = base_max_health * multiplier
	health = max_health

	armour = base_armour * multiplier

	patrol_speed = base_patrol_speed * multiplier
	chase_speed = base_chase_speed * multiplier

	attack_damage = roundi(base_attack_damage * multiplier)


#########################################
# References

var player : CharacterBody3D

@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D


#########################################
# States

var is_aggravated := false
var can_attack := true


#########################################
# Knockback

var knockback_velocity := Vector3.ZERO
@export var knockback_decay := 7.0


#########################################
# Setup

func _ready() -> void:
	base_max_health = max_health
	base_armour = armour
	base_patrol_speed = patrol_speed
	base_chase_speed = chase_speed
	base_attack_damage = attack_damage

	health = max_health

	add_to_group("enemies")


#########################################
# Physics

func _physics_process(delta: float) -> void:
	if player == null:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	var distance = global_position.distance_to(player.global_position)

	if distance <= detection_range:
		is_aggravated = true

	if is_aggravated:
		chase_player()
	else:
		velocity.x = move_toward(velocity.x, 0, patrol_speed)
		velocity.z = move_toward(velocity.z, 0, patrol_speed)

	velocity.x += knockback_velocity.x
	velocity.z += knockback_velocity.z

	knockback_velocity = knockback_velocity.lerp(
		Vector3.ZERO,
		knockback_decay * delta
	)

	move_and_slide()


#########################################
# Chase

func chase_player() -> void:
	if player == null:
		return

	var distance = global_position.distance_to(player.global_position)

	if distance <= attack_range:
		velocity.x = 0
		velocity.z = 0
		attack_player()
		return

	if nav_agent == null:
		return

	nav_agent.set_target_position(player.global_position)

	var next_point = nav_agent.get_next_path_position()

	var direction = next_point - global_position
	direction.y = 0
	direction = direction.normalized()

	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed


#########################################
# Knockback

func apply_knockback(force: Vector3) -> void:
	force.y = 0
	knockback_velocity += force


#########################################
# Attack

func attack_player() -> void:
	if not can_attack:
		return

	if not is_inside_tree():
		return

	can_attack = false

	if player != null and player.has_method("take_damage"):
		player.take_damage(attack_damage)

	var tree = get_tree()

	if tree == null:
		return

	await tree.create_timer(attack_cooldown).timeout

	if not is_inside_tree():
		return

	can_attack = true


#########################################
# Gunshot Detection

func hear_gunshot(gunshot_position: Vector3) -> void:
	var distance = global_position.distance_to(gunshot_position)

	if distance <= hearing_range:
		is_aggravated = true


#########################################
# Damage

func take_damage(amount: int) -> void:
	var final_damage = amount - armour
	final_damage = max(1, final_damage)

	health -= final_damage

	print("Enemy Health: ", health)

	is_aggravated = true

	if health <= 0:
		die()


func die() -> void:
	queue_free()
