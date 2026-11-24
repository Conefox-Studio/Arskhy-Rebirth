extends StaticBody2D
var owner_level


func hit(_dmg: int, _dir: float) -> void:
	if owner_level != null and is_instance_valid(owner_level):
		owner_level.hive_hit()
