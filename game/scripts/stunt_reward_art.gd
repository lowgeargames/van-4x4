extends Control
## Geometria 2D barata: placa recortada, estrela e doze riscos de celebração.
@export var kind: int = 0
var origin := Vector2.ZERO:
	set(value):
		origin = value
		queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	if kind == 0:
		var w: float = size.x
		var h: float = size.y
		draw_colored_polygon(PackedVector2Array([Vector2(14,0),Vector2(w,0),Vector2(w,h-14),Vector2(w-14,h),Vector2(0,h),Vector2(0,14)]), Color("182126ed"))
		draw_colored_polygon(PackedVector2Array([Vector2(14,0),Vector2(88,0),Vector2(80,5),Vector2(9,5)]), Color("ff742e"))
		draw_line(Vector2(w-76,h-3),Vector2(w-14,h-3),Color("ffc83d"),3,true)
	elif kind == 1:
		var points := PackedVector2Array()
		var center := size * 0.5
		for i in 10:
			points.append(center + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * (27.0 if i % 2 == 0 else 12.0))
		draw_set_transform(Vector2(2,3))
		draw_colored_polygon(points, Color("9b5725"))
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(points, Color("ffc83d"))
		draw_line(center+Vector2(-6,-7),center+Vector2(-2,-17),Color("fff3d6"),3,true)
	else:
		for i in 12:
			var direction := Vector2.from_angle(i * TAU / 12.0)
			draw_line(origin+direction*62.0,origin+direction*(77.0 if i%2==0 else 71.0),Color("ffc83d") if i%2==0 else Color("fff3d6"),3,true)
