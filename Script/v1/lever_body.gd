extends StaticBody2D
var owner_level


func hit(_dmg: int, _dir: float) -> void:
	if owner_level != null and is_instance_valid(owner_level):
		var pl = owner_level.get("_player")
		if pl != null:
			pl.set("lever_magic", bool(get_meta("by_magic", false)))
		owner_level.lever_hit()
		if pl != null:
			pl.set("lever_magic", false)
