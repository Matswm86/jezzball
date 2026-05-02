extends Node2D

# DIAGNOSTIC v0.1.1 — minimal _draw to verify root Node2D renders on the user's
# device. If this shows red + green + cyan, full game code is restored next push.
# If this shows pure black, the bug is in scene loading or renderer config.

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Full-screen red so a successful render is impossible to miss.
	draw_rect(Rect2(0, 0, 1080, 1920), Color(1.0, 0.0, 0.0, 1.0), true)
	# Green square top-left.
	draw_rect(Rect2(80, 80, 400, 400), Color(0.0, 1.0, 0.0, 1.0), true)
	# Cyan square bottom-right.
	draw_rect(Rect2(600, 1400, 400, 400), Color(0.0, 1.0, 1.0, 1.0), true)
	# Yellow strip across the middle.
	draw_rect(Rect2(0, 900, 1080, 120), Color(1.0, 1.0, 0.0, 1.0), true)
