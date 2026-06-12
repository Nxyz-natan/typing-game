extends Node2D

var active_enemy = null
var current_level_index: int = -1


func find_new_active_enemy(typed_character: String):
	var prompt = $enemies.get_prompt()
	if prompt.substr(0,1) == typed_character:
		active_enemy = $enemies
		print("new_enemy")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.is_pressed():
		var typed_event = event as InputEventKey
		var key_typed = PackedByteArray([typed_event.unicode]).get_string_from_utf8()
		if active_enemy == null:
			find_new_active_enemy(key_typed)
