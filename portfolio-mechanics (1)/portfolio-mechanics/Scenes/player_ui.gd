extends CanvasLayer

#########################################
# References

@export var player : CharacterBody3D

@export var health_bar : ProgressBar
@export var stamina_bar : ProgressBar

@export var helmet_layer : Control
@export var damage_flash : ColorRect

@export var wave_label : Label


#########################################
# UI Drift

@export var drift_amount := 12.0
@export var drift_speed := 8.0

@export var jump_drift_amount := 18.0
@export var recoil_drift_amount := 10.0

var target_offset := Vector2.ZERO


#########################################
# Damage Flash

@export var flash_fade_speed := 4.0

var last_health := 0.0


#########################################
# Setup

func _ready() -> void:
	if player == null:
		return

	health_bar.max_value = player.max_health
	health_bar.value = player.health

	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina

	last_health = player.health

	if damage_flash != null:
		damage_flash.color = Color(1, 0, 0, 0)

	if wave_label != null:
		wave_label.visible = false
		wave_label.text = ""

	style_bar(health_bar, Color(0.35, 1.0, 0.65, 1.0))
	style_bar(stamina_bar, Color(1.0, 0.65, 0.2, 1.0))


#########################################
# Update

func _process(delta: float) -> void:
	if player == null:
		return

	health_bar.max_value = player.max_health
	health_bar.value = player.health

	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina

	handle_helmet_drift(delta)
	handle_damage_flash(delta)


#########################################
# Helmet Drift

func handle_helmet_drift(delta: float) -> void:
	var mouse_velocity = Input.get_last_mouse_velocity()

	var controller_look := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)

	var combined_input = Vector2(
		(-mouse_velocity.x * 0.015) + (-controller_look.x * 12.0),
		(-mouse_velocity.y * 0.015) + (-controller_look.y * 12.0)
	)

	target_offset = Vector2(
		clamp(combined_input.x, -drift_amount, drift_amount),
		clamp(combined_input.y, -drift_amount, drift_amount)
	)

	target_offset.y += player.velocity.y * -0.9
	target_offset.y += player.ui_jump_kick * jump_drift_amount
	target_offset.y += player.ui_recoil_kick * recoil_drift_amount

	helmet_layer.position = helmet_layer.position.lerp(
		target_offset,
		drift_speed * delta
	)


#########################################
# Damage Flash

func handle_damage_flash(delta: float) -> void:
	if damage_flash == null:
		return

	if player.health < last_health:
		damage_flash.color.a = 0.45

	damage_flash.color.a = lerp(
		damage_flash.color.a,
		0.0,
		flash_fade_speed * delta
	)

	last_health = player.health


#########################################
# Wave Announcement

func announce_wave(
	wave_number: int,
	player_level: int,
	enemy_level: int
) -> void:
	if wave_label == null:
		print("WaveLabel not assigned")
		return

	wave_label.visible = true

	wave_label.text = (
		"WAVE " + str(wave_number) +
		"\nPLAYER LEVEL " + str(player_level) +
		"\nENEMY LEVEL " + str(enemy_level)
	)

	await get_tree().create_timer(4.0).timeout

	if wave_label != null:
		wave_label.visible = false


#########################################
# UI Style

func style_bar(bar: ProgressBar, fill_color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.03, 0.04, 0.04, 0.75)
	background.border_color = Color(0.45, 0.55, 0.55, 1.0)
	background.set_border_width_all(2)
	background.set_corner_radius_all(0)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(0)

	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	bar.show_percentage = false
