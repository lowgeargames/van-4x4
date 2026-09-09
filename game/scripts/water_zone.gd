extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("enter_water"):
		body.enter_water()


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("exit_water"):
		body.exit_water()
