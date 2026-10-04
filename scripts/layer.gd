extends Node2D
# Kleiner Helfer: ein Node2D, das seine Zeichen-Routine von außen bekommt.
var cb: Callable

func _draw() -> void:
	if cb.is_valid():
		cb.call(self)
