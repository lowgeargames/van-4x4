extends Area3D

## Apenas apresentação dos respingos; desligado nas zonas antigas.
@export var align_splashes_to_surface: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("enter_water"):
		if align_splashes_to_surface:
			body.set_meta("water_surface_height", global_position.y)
		body.enter_water()


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("exit_water"):
		if align_splashes_to_surface and body.has_meta("water_surface_height"):
			body.remove_meta("water_surface_height")
		body.exit_water()
