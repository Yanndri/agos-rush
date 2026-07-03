extends Node
class_name YapperTweens

static func panel_in(control: Control, duration := 0.18, from_scale := Vector2(0.92, 0.92)):
	if control == null:
		return null

	control.visible = true
	control.modulate.a = 0.0
	control.scale = from_scale
	control.pivot_offset = control.size * 0.5

	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


static func panel_out(control: Control, duration := 0.14, to_scale := Vector2(0.96, 0.96)):
	if control == null:
		return null

	control.pivot_offset = control.size * 0.5

	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(control, "scale", to_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(control):
			control.visible = false
	)
	return tween
