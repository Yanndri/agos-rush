extends Node3D
class_name HelpRequirement

signal fulfilled(item: PickableItem)

const AVAILABLE_REQUIREMENTS := {
	"Medkit": {
		"item_name": "FirstAidKit",
		"visual_node": "Medkit",
	},
	"FoodSupply": {
		"item_name": "FoodSupply",
		"visual_node": "FoodSupply",
	},
	"Battery": {
		"item_name": "Battery",
		"visual_node": "Battery",
	},
	"Hospital": {
		"item_name": "",
		"visual_node": "Hospital",
	},
}

@export_enum("Medkit", "FoodSupply", "Battery") var requirement_type := "Medkit":
	set(value):
		requirement_type = value
		_update_visuals()

# Kept so older scene data using a typed item name still loads.
var required_item_name := ""

@export var consume_item_when_fulfilled := true
@export var interact_action := "interact"
@export var hold_duration := 2.0
@export var requirements_visual_path: NodePath = NodePath("Requirements")
@export var prompt_area_path: NodePath = NodePath("PromptArea")
@export var progress_label_path: NodePath = NodePath("PromptArea/Control/PromptLabel")
@export var default_prompt_text := "[F] to Interact"
@export var idle_prompt_text := "Hold [F] to Use"
@export var use_progress_text := "Using... %d%%"

var _requirement_fulfilled := false
var _show_fulfilled_requirement_visual := false
var nearby_player: CharacterBody3D
var hold_time := 0.0
var is_holding := false

@export var requirement_fulfilled := false:
	set(value):
		_set_fulfilled(value)
	get:
		return _requirement_fulfilled

@onready var requirements_visual: Node3D = get_node_or_null(requirements_visual_path) as Node3D
@onready var prompt_area: PromptArea = get_node_or_null(prompt_area_path) as PromptArea
@onready var progress_label: Label = get_node_or_null(progress_label_path) as Label


func _ready() -> void:
	_update_visuals()
	_update_progress_label()

	if prompt_area == null:
		push_warning("HelpRequirement PromptArea path is wrong: " + str(prompt_area_path))
		return

	if not prompt_area.local_player_entered.is_connected(_on_prompt_area_local_player_entered):
		prompt_area.local_player_entered.connect(_on_prompt_area_local_player_entered)

	if not prompt_area.local_player_exited.is_connected(_on_prompt_area_local_player_exited):
		prompt_area.local_player_exited.connect(_on_prompt_area_local_player_exited)

	_check_overlapping_players()


func _process(delta: float) -> void:
	if requirement_fulfilled:
		return

	if nearby_player == null:
		_hide_progress_label()
		return

	if not _player_has_required_item(nearby_player):
		_cancel_hold_interact()
		return

	if not Input.is_action_pressed(interact_action):
		_cancel_hold_interact()
		return

	if not is_holding:
		_start_hold_interact()

	hold_time += delta
	_update_progress_label()

	if hold_time >= hold_duration:
		_finish_hold_interact()


func _on_prompt_area_local_player_entered(player: CharacterBody3D) -> void:
	if not _is_local_player(player):
		return

	nearby_player = player
	_update_progress_label()


func _on_prompt_area_local_player_exited(player: CharacterBody3D) -> void:
	if player != nearby_player:
		return

	nearby_player = null
	_cancel_hold_interact()


func _check_overlapping_players() -> void:
	if prompt_area != null and _is_local_player(prompt_area.current_local_player):
		nearby_player = prompt_area.current_local_player
		_update_progress_label()
		return

	nearby_player = null
	_hide_progress_label()


func _try_fulfill_from_node(node: Node) -> bool:
	if requirement_fulfilled:
		return false

	var item := _find_pickable_item(node)
	if item == null:
		return false

	if item.picked_up:
		return false

	if not _is_required_item(item):
		return false

	_fulfill(item)
	return true


func _find_pickable_item(node: Node) -> PickableItem:
	var current := node
	while current != null:
		var item := current as PickableItem
		if item != null:
			return item
		current = current.get_parent()

	return null


func _is_required_item(item: PickableItem) -> bool:
	var item_requirement_name := _get_required_item_name()
	if item_requirement_name.is_empty():
		return true

	var item_name := String(item.name)
	return item_name == item_requirement_name or item_name.begins_with(item_requirement_name)


func _start_hold_interact() -> void:
	is_holding = true
	hold_time = 0.0
	_update_progress_label()


func _cancel_hold_interact() -> void:
	is_holding = false
	hold_time = 0.0
	_update_progress_label()


func _finish_hold_interact() -> void:
	var item := _get_player_required_item(nearby_player)
	if item == null:
		_cancel_hold_interact()
		return

	_cancel_hold_interact()

	if multiplayer.multiplayer_peer == null:
		_fulfill(item)
	elif multiplayer.is_server():
		_apply_fulfill.rpc(item.get_path())
	else:
		_request_fulfill.rpc_id(1, item.get_path())


@rpc("any_peer", "reliable")
func _request_fulfill(item_path: NodePath) -> void:
	if not multiplayer.is_server():
		return

	var item := get_node_or_null(item_path) as PickableItem
	if item == null or not _is_required_item(item):
		return

	_apply_fulfill.rpc(item_path)


@rpc("authority", "call_local", "reliable")
func _apply_fulfill(item_path: NodePath) -> void:
	var item := get_node_or_null(item_path) as PickableItem
	if item == null:
		return

	_fulfill(item)


func _fulfill(item: PickableItem) -> void:
	if requirement_fulfilled:
		return

	_set_fulfilled(true)
	print("HELP REQUIREMENT FULFILLED | requirement=", name, " | item=", item.name)

	if consume_item_when_fulfilled:
		_consume_item(item)

	fulfilled.emit(item)


func _set_fulfilled(value: bool) -> void:
	_requirement_fulfilled = value
	if not value:
		_show_fulfilled_requirement_visual = false
	_update_visuals()


func show_fulfilled_requirement(requirement_key: String) -> void:
	if not AVAILABLE_REQUIREMENTS.has(requirement_key):
		push_warning("Unknown fulfilled requirement display: " + requirement_key)
		return

	requirement_type = requirement_key
	_show_fulfilled_requirement_visual = true
	_update_visuals()


func _consume_item(item: PickableItem) -> void:
	var holder := item.holder
	if holder != null:
		var interactor := holder.get_node_or_null("PlayerPickupInteractor") as PlayerPickupInteractor
		if interactor != null:
			interactor.clear_held_item(item)

	item.picked_up = true
	item.visible = false
	item.process_mode = Node.PROCESS_MODE_DISABLED

	if item.prompt_area != null:
		item.prompt_area.set_prompt_enabled(false)


func _update_visuals() -> void:
	if requirements_visual != null:
		requirements_visual.visible = not _requirement_fulfilled or _show_fulfilled_requirement_visual
		_update_requirement_visuals()


func _update_requirement_visuals() -> void:
	if requirements_visual == null:
		return

	for requirement in AVAILABLE_REQUIREMENTS.values():
		var visual_name := String(requirement.get("visual_node", ""))
		var visual := requirements_visual.get_node_or_null(visual_name) as Node3D
		if visual != null:
			visual.visible = false

	var selected_requirement := _get_requirement_data()
	var selected_visual_name := String(selected_requirement.get("visual_node", ""))
	var selected_visual := requirements_visual.get_node_or_null(selected_visual_name) as Node3D
	if selected_visual != null:
		selected_visual.visible = not _requirement_fulfilled or _show_fulfilled_requirement_visual


func _get_requirement_data() -> Dictionary:
	return AVAILABLE_REQUIREMENTS.get(requirement_type, {})


func _get_required_item_name() -> String:
	if not required_item_name.is_empty():
		return required_item_name

	return String(_get_requirement_data().get("item_name", ""))


func _update_progress_label() -> void:
	if progress_label == null:
		return

	if nearby_player == null:
		_hide_progress_label()
		return

	progress_label.visible = true

	if is_holding:
		var percent := int(clamp(hold_time / hold_duration, 0.0, 1.0) * 100.0)
		progress_label.text = use_progress_text % percent
	elif _player_has_held_item(nearby_player):
		progress_label.text = idle_prompt_text
	else:
		progress_label.text = default_prompt_text


func _hide_progress_label() -> void:
	if progress_label != null:
		progress_label.visible = false


func _player_has_required_item(player: CharacterBody3D) -> bool:
	return _get_player_required_item(player) != null


func player_has_required_item(player: CharacterBody3D) -> bool:
	return _player_has_required_item(player)


func _player_has_held_item(player: CharacterBody3D) -> bool:
	return _get_player_held_item(player) != null


func _get_player_held_item(player: CharacterBody3D) -> PickableItem:
	if player == null:
		return null

	var inventory := player.get_node_or_null("PlayerInventory") as PlayerInventory
	if inventory == null:
		return null

	var item := inventory.get_selected_item()
	if item == null or not is_instance_valid(item):
		return null

	return item


func _get_player_required_item(player: CharacterBody3D) -> PickableItem:
	var item := _get_player_held_item(player)
	if item == null:
		return null

	if not _is_required_item(item):
		return null

	return item


func _is_local_player(body: Node) -> bool:
	if body == null:
		return false

	if not body is CharacterBody3D:
		return false

	if body.get_node_or_null("PlayerInventory") == null:
		return false

	if body.has_method("is_multiplayer_authority"):
		if multiplayer.multiplayer_peer != null and not body.is_multiplayer_authority():
			return false

	return true
