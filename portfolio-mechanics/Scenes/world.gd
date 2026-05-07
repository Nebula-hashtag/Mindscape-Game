extends Node3D

@onready var player: Node3D = $Player

func _physics_process(delta: float) -> void:
	get_tree().call_group("Enemies", "update_target_local", player.global_transform.origin)
