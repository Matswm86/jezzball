extends Node2D

# DIAGNOSTIC v3 — minimal Game.gd
# Build tag visible bottom-left: a wide MAGENTA strip (260 wide x 100 tall at y=1700).
# This color/position exists ONLY in this build, so seeing it confirms the APK on the
# device is the new one (not a cached old install).
#
# Then 4 milestone squares across the bottom at y=1820:
#   RED    — _ready entered
#   GREEN  — _ready halfway
#   BLUE   — _ready three-quarters
#   YELLOW — _ready completed
#
# A solid LIGHT-CYAN background is drawn first so we can also tell whether _draw fires.

func _ready() -> void:
	_diag_rect(0, Color(1, 0, 1), 1700)   # MAGENTA build tag
	_diag_rect(0, Color(1, 0, 0), 1820)   # RED — _ready entered
	var dummy_a = 1 + 1
	_diag_rect(1, Color(0, 1, 0), 1820)   # GREEN — past first statement
	var dummy_b = "string-test"
	_diag_rect(2, Color(0, 0, 1), 1820)   # BLUE — past second statement
	for i in 3:
		dummy_a += i
	_diag_rect(3, Color(1, 1, 0), 1820)   # YELLOW — _ready done

func _diag_rect(idx: int, c: Color, y: float) -> void:
	var r := ColorRect.new()
	r.color = c
	r.position = Vector2(idx * 270 + 5, y)
	r.size = Vector2(260, 100)
	add_child(r)

func _draw() -> void:
	# Light cyan top half so we can tell _draw is firing too.
	draw_rect(Rect2(0, 0, 1080, 1500), Color(0.5, 0.9, 1.0, 1.0), true)
