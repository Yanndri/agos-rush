extends PickableItem
class_name FirstAidKit

@export var heal_amount := 25


func on_picked_up(player: Node3D) -> void:
	print(player, " Picked up first aid kit.")


func on_used(player: Node3D) -> void:
	print(player, " Used first aid kit. Heal amount: ", heal_amount)

	# Example if your player has a heal function:
	if player.has_method("heal"):
		player.heal(heal_amount)

	# Remove the item after use.
	queue_free()
