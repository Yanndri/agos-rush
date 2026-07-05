extends MarginContainer

@export_file("*.tscn") var main_menu_scene: String = "res://scenes/main_menu.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_main_menu_pressed() -> void:
	if multiplayer.multiplayer_peer != null:
		NetworkManager.leave_game()

	get_tree().change_scene_to_file(main_menu_scene)
