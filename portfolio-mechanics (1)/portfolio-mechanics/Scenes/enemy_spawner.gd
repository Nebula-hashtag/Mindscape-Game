extends Node3D

#########################################
# References

@export var player : CharacterBody3D
@export var player_ui : CanvasLayer

# Order:
# 0 = normal
# 1 = large
# 2 = small
@export var enemy_scenes : Array[PackedScene] = []


#########################################
# Spawn Settings

@export var max_enemies := 50

@export var min_spawn_distance := 15.0
@export var max_spawn_distance := 35.0


#########################################
# Stage Progression

# Stage is for planet progression later.
# Every stage increases spawn pressure by 25%.
@export var current_stage := 1
@export var spawn_rate_increase_per_stage := 0.25


#########################################
# Wave Settings

var current_wave := 0
var enemy_level := 1

@export var wave_interval := 30.0
@export var waves_before_break := 3
@export var break_time := 60.0

@export var base_wave_enemy_amount := 4
@export var enemies_added_per_wave := 2

@export var wave_spawn_spacing := 0.2

var waves_since_break := 0
var is_wave_active := false
var is_break_active := false


#########################################
# Ambient Spawn Settings

@export var ambient_spawning_enabled := true
@export var ambient_spawn_delay := 10.0
@export var ambient_spawn_chance := 60
@export var ambient_enemy_amount := 1


#########################################
# Enemy Rarity

@export var small_enemy_chance := 60
@export var normal_enemy_chance := 30
@export var large_enemy_chance := 10


#########################################
# Enemy Tracking

var current_enemies := []


#########################################
# Setup

func _ready() -> void:
	randomize()

	if player != null and player.has_method("set_player_stage"):
		player.set_player_stage(current_stage)

	wave_loop()

	if ambient_spawning_enabled:
		ambient_spawn_loop()


#########################################
# Stage Multiplier

func get_stage_spawn_multiplier() -> float:
	return 1.0 + ((current_stage - 1) * spawn_rate_increase_per_stage)


#########################################
# Wave Loop

func wave_loop() -> void:
	while true:
		await get_tree().create_timer(wave_interval).timeout

		await start_wave()

		if waves_since_break >= waves_before_break:
			await start_break()


#########################################
# Ambient Spawn Loop

func ambient_spawn_loop() -> void:
	while true:
		await get_tree().create_timer(ambient_spawn_delay).timeout

		if is_wave_active:
			continue

		if is_break_active:
			continue

		clean_enemy_list()

		if current_enemies.size() >= max_enemies:
			continue

		var stage_multiplier = get_stage_spawn_multiplier()

		var scaled_chance = clamp(
			roundi(ambient_spawn_chance * stage_multiplier),
			1,
			100
		)

		var roll = randi_range(1, 100)

		if roll > scaled_chance:
			continue

		var scaled_amount = max(
			1,
			roundi(ambient_enemy_amount * stage_multiplier)
		)

		for i in range(scaled_amount):
			if current_enemies.size() >= max_enemies:
				break

			spawn_enemy()


#########################################
# Start Wave

func start_wave() -> void:
	is_wave_active = true

	current_wave += 1
	enemy_level = current_wave
	waves_since_break += 1

	if player != null and player.has_method("set_player_level"):
		player.set_player_level(current_wave)

	if player != null and player.has_method("set_player_stage"):
		player.set_player_stage(current_stage)

	if player_ui != null and player_ui.has_method("announce_wave"):
		player_ui.announce_wave(
			current_wave,
			player.player_level,
			enemy_level
		)

	print("WAVE ", current_wave)
	print("STAGE ", current_stage)
	print("PLAYER LEVEL ", player.player_level)
	print("ENEMY LEVEL ", enemy_level)

	var stage_multiplier = get_stage_spawn_multiplier()

	var enemies_this_wave = roundi(
		(
			base_wave_enemy_amount +
			((current_wave - 1) * enemies_added_per_wave)
		)
		*
		stage_multiplier
	)

	for i in range(enemies_this_wave):
		clean_enemy_list()

		if current_enemies.size() >= max_enemies:
			break

		spawn_enemy()

		await get_tree().create_timer(wave_spawn_spacing).timeout

	is_wave_active = false


#########################################
# Break

func start_break() -> void:
	is_break_active = true
	waves_since_break = 0

	print("BREAK STARTED")

	await get_tree().create_timer(break_time).timeout

	is_break_active = false

	print("BREAK FINISHED")


#########################################
# Spawn Enemy

func spawn_enemy() -> void:
	if player == null:
		print("EnemySpawner missing player")
		return

	if enemy_scenes.size() < 3:
		print("EnemySpawner needs 3 enemy scenes")
		return

	var enemy_scene = pick_weighted_enemy_scene()

	if enemy_scene == null:
		return

	var enemy = enemy_scene.instantiate()

	get_tree().current_scene.add_child(enemy)

	enemy.global_position = get_random_spawn_position()

	enemy.player = player

	if enemy.has_method("set_enemy_level"):
		enemy.set_enemy_level(enemy_level)

	current_enemies.append(enemy)

	print("Enemy spawned")


#########################################
# Enemy Rarity Pick

func pick_weighted_enemy_scene() -> PackedScene:
	var total_chance = (
		small_enemy_chance +
		normal_enemy_chance +
		large_enemy_chance
	)

	var roll = randi_range(1, total_chance)

	if roll <= small_enemy_chance:
		return enemy_scenes[2]

	elif roll <= small_enemy_chance + normal_enemy_chance:
		return enemy_scenes[0]

	else:
		return enemy_scenes[1]


#########################################
# Spawn Position

func get_random_spawn_position() -> Vector3:
	var random_angle = randf() * TAU

	var random_distance = randf_range(
		min_spawn_distance,
		max_spawn_distance
	)

	var offset = Vector3(
		cos(random_angle) * random_distance,
		0,
		sin(random_angle) * random_distance
	)

	return player.global_position + offset


#########################################
# Enemy List Cleanup

func clean_enemy_list() -> void:
	current_enemies = current_enemies.filter(
		func(enemy): return is_instance_valid(enemy)
	)
