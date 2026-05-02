extends Node2D

# DIAGNOSTIC v5 — bisect _build_ui line-by-line.
# Top row (y=1820, 4 squares): main _ready milestones — all 4 mean _build_ui returned.
# Sub-row (y=1700, up to 7 colored stripes): a marker is placed AFTER each line of
# _build_ui that finished. The first MISSING stripe identifies the failing line.

const COLS := 36
const ROWS := 56
const CELL := 30.0
const FIELD_X := 0.0
const FIELD_Y := 160.0
const FIELD_W := COLS * CELL
const FIELD_H := ROWS * CELL

const HUD_H := 160.0
const CTRL_Y := FIELD_Y + FIELD_H
const CTRL_H := 80.0

const COL_TEXT := Color(0.0, 0.0, 0.0)

var lbl_level: Label
var lbl_lives: Label
var lbl_pct: Label
var lbl_orient: Label
var lbl_restart: Label
var lbl_overlay_title: Label
var lbl_overlay_sub: Label
var overlay_box: ColorRect

func _ready() -> void:
	_diag_rect(0, Color(1, 0, 1), 1580)   # MAGENTA tag for v5
	_diag_rect(0, Color(1, 0, 0), 1820)   # RED — _ready entered
	_build_ui()
	_diag_rect(1, Color(0, 1, 0), 1820)   # GREEN — _build_ui returned
	_diag_rect(2, Color(0, 0, 1), 1820)   # BLUE
	_diag_rect(3, Color(1, 1, 0), 1820)   # YELLOW

# Each sub-marker uses idx 0..6 along y=1700 in a dim-orange shade.
# Visible == "this line of _build_ui executed". First missing marker = first failing line.
func _build_ui() -> void:
	_sub(0)   # entered _build_ui
	lbl_level = _make_label(Vector2(20, 20), 400, 36)
	_sub(1)   # _make_label call 1
	lbl_lives = _make_label(Vector2(20, 70), 400, 36)
	_sub(2)
	lbl_pct = _make_label(Vector2(FIELD_W - 420, 20), 400, 36, HORIZONTAL_ALIGNMENT_RIGHT)
	_sub(3)
	overlay_box = ColorRect.new()
	overlay_box.color = Color(0, 0, 0, 0.78)
	overlay_box.position = Vector2(0, FIELD_Y + FIELD_H * 0.35)
	overlay_box.size = Vector2(FIELD_W, 280)
	overlay_box.visible = false
	add_child(overlay_box)
	_sub(4)
	lbl_overlay_title = _make_label(Vector2(0, FIELD_Y + FIELD_H * 0.35 + 60), FIELD_W, 56, HORIZONTAL_ALIGNMENT_CENTER)
	_sub(5)
	lbl_overlay_title.add_theme_color_override("font_color", Color(1, 1, 1))
	_sub(6)

func _make_label(pos: Vector2, w: float, fs: int, halign: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(w, fs * 1.6)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", COL_TEXT)
	l.horizontal_alignment = halign
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l

func _sub(idx: int) -> void:
	# Bright orange stripe at y=1700, packed left-to-right so 7 fit across.
	var w := 150
	var r := ColorRect.new()
	r.color = Color(1.0, 0.5, 0.0)
	r.position = Vector2(idx * (w + 5) + 5, 1700)
	r.size = Vector2(w, 100)
	add_child(r)

func _diag_rect(idx: int, c: Color, y: float) -> void:
	var r := ColorRect.new()
	r.color = c
	r.position = Vector2(idx * 270 + 5, y)
	r.size = Vector2(260, 100)
	add_child(r)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1080, 1500), Color(0.5, 0.9, 1.0, 1.0), true)
