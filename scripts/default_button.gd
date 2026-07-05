extends Button

@export var click_sfx: AudioStream = preload("res://Music/driken5482-retro-blip-236676.mp3")
@export var hover_sfx: AudioStream = preload("res://Music/47313572-ui-sounds-pack-3-10-359727.mp3")

func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)


func _on_pressed() -> void:
	AudioUtility.play_sfx_2d(self, click_sfx)


func _on_mouse_entered() -> void:
	AudioUtility.play_sfx_2d(self, hover_sfx)
