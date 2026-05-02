extends Node2D

# v0.6 minimal verification build
# Filename of the APK has been changed to jezzball-fresh.apk so the device
# CANNOT serve a cached copy from any previous install.
#
# Two independent visual markers:
#   1. RED ColorRect node added in _ready  → visible if the script class
#      registered and _ready() actually ran on the device.
#   2. YELLOW strip drawn via _draw          → visible if _draw() also runs.
#
# If you see both: the engine is fine, our problem in the full v0.4/v0.5 code
# was a real class-load bug from a particular GDScript construct.
# If you see only red: _ready works but _draw is failing for some reason.
# If you see only yellow: shouldn't happen.
# If you see neither but the screen isn't white: something else is going on.
# If you see pure white: the APK on the device is STILL not this one.

func _ready() -> void:
	var r := ColorRect.new()
	r.color = Color(1, 0, 0)              # bright red
	r.position = Vector2(0, 200)
	r.size = Vector2(1080, 200)
	add_child(r)

func _draw() -> void:
	# Light cyan top half so the screen isn't ambiguous.
	draw_rect(Rect2(0, 0, 1080, 1920), Color(0.5, 0.9, 1.0, 1.0), true)
	# Yellow strip across the very top.
	draw_rect(Rect2(0, 0, 1080, 80), Color(1, 1, 0, 1), true)
