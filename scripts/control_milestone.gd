extends Control

@export var max_messages := 8

const TEXT_CHAT_GROUP := "text_chat"

@onready var history_label: RichTextLabel = $Panel/VBoxContainer/HistoryLabel
@onready var message_edit: LineEdit = $Panel/VBoxContainer/InputRow/MessageEdit

var messages: Array[String] = []

func _ready() -> void:
	add_to_group(TEXT_CHAT_GROUP)
	_add_local_system_message("Player Connected")

func _on_message_edit_text_submitted(_new_text: String) -> void:
	_send_current_message()

func _on_send_button_pressed() -> void:
	_send_current_message()

func _send_current_message() -> void:
	var message := message_edit.text.strip_edges()
	if message.is_empty():
		return
	message_edit.clear()

	if multiplayer.multiplayer_peer == null:
		_receive_chat_message(1, message)
	elif multiplayer.is_server():
		_receive_chat_message.rpc(multiplayer.get_unique_id(), message)
	else:
		_request_chat_message.rpc_id(1, message)

@rpc("any_peer", "reliable")
func _request_chat_message(message: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_receive_chat_message.rpc(sender_id, message)

@rpc("authority", "call_local", "reliable")
func _receive_chat_message(sender_id: int, message: String) -> void:
	var display_name := "[b]Player %s[/b]" % sender_id
	_add_message("%s: [i]%s[/i]" % [display_name, message])

func _add_local_system_message(message: String) -> void:
	_add_message("[i]%s[/i]" % message)

func add_system_message(message: String) -> void:
	if message.strip_edges().is_empty():
		return

	_add_local_system_message(message)

func broadcast_system_message(message: String) -> void:
	if message.strip_edges().is_empty():
		return

	if multiplayer.multiplayer_peer == null:
		_receive_system_message(message)
	elif multiplayer.is_server():
		_receive_system_message.rpc(message)
	else:
		_request_system_message.rpc_id(1, message)

@rpc("any_peer", "reliable")
func _request_system_message(message: String) -> void:
	if not multiplayer.is_server():
		return

	_receive_system_message.rpc(message)

@rpc("authority", "call_local", "reliable")
func _receive_system_message(message: String) -> void:
	_add_local_system_message(message)

func _add_message(message: String) -> void:
	messages.append(message)
	while messages.size() > max_messages:
		messages.remove_at(0)
	history_label.text = "\n".join(messages)
