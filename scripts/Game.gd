extends Node2D

# DIAGNOSTIC v7 — bisect of v6 (12 functions). v7 keeps 6 functions, removes 6.
# If markers reappear: bug is in REMOVED set (advance_walls, wall_cell, flood,
# region_has_ball, update_balls, ball_overlaps_cell).
# If markers stay missing: bug is in KEPT set.

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

const COL_BG := Color(0.827, 0.827, 0.827)
const COL_FIELD := Color(0.827, 0.827, 0.827)
const COL_BORDER := Color(0.663, 0.663, 0.663)
const COL_WALL := Color(0.722, 0.396, 0.400)
const COL_BUILDING := Color(0.467, 0.184, 0.196)
const COL_CAPTURED := Color(0.506, 0.529, 0.871)
const COL_BALL := Color(0.722, 0.396, 0.400)
const COL_BALL_PATTERN := Color(1.0, 1.0, 1.0)
const COL_BALL_OUTLINE := Color(0.4, 0.18, 0.18)
const COL_TEXT := Color(0.0, 0.0, 0.0)
const COL_BTN := Color(0.95, 0.95, 0.95)
const COL_BTN_BORDER := Color(0.4, 0.4, 0.4)
const COL_BAR_BG := Color(0.7, 0.7, 0.7)
const COL_BAR_FILL := Color(0.506, 0.529, 0.871)

const BALL_RADIUS := 13.0
const BALL_SPEED := 240.0
const WALL_SPEED := 6.5
const TARGET := 0.75
const MAX_LEVEL := 50

enum CellState { EMPTY, BORDER, WALL, BUILDING, CAPTURED }
enum GameState { PLAYING, LEVEL_WIN, LEVEL_LOSE }

var grid: Array = []
var balls: Array = []
var walls: Array = []
var orient_vertical := true

var level := 1
var lives := 3
var captured := 0
var play_total := 0
var state: int = GameState.PLAYING
var intro_timer := 0.0

var lbl_level: Label
var lbl_lives: Label
var lbl_pct: Label
var lbl_orient: Label
var lbl_restart: Label
var lbl_overlay_title: Label
var lbl_overlay_sub: Label
var overlay_box: ColorRect

func _ready() -> void:
	_diag_rect(0, Color(1, 0, 1), 1580)   # MAGENTA build tag (v7)
	_diag_rect(0, Color(1, 0, 0), 1820)
	_diag_rect(1, Color(0, 1, 0), 1820)
	_diag_rect(2, Color(0, 0, 1), 1820)
	_diag_rect(3, Color(1, 1, 0), 1820)

func _build_ui() -> void:
	lbl_level = _make_label(Vector2(20, 20), 400, 36)
	lbl_lives = _make_label(Vector2(20, 70), 400, 36)
	lbl_pct = _make_label(Vector2(FIELD_W - 420, 20), 400, 36, HORIZONTAL_ALIGNMENT_RIGHT)
	var btn_w := FIELD_W * 0.5 - 20
	lbl_orient = _make_label(Vector2(10, CTRL_Y + 10), btn_w, 30, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_restart = _make_label(Vector2(FIELD_W * 0.5 + 10, CTRL_Y + 10), btn_w, 30, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_restart.text = "RESTART"
	overlay_box = ColorRect.new()
	overlay_box.color = Color(0, 0, 0, 0.78)
	overlay_box.position = Vector2(0, FIELD_Y + FIELD_H * 0.35)
	overlay_box.size = Vector2(FIELD_W, 280)
	overlay_box.visible = false
	add_child(overlay_box)
	lbl_overlay_title = _make_label(Vector2(0, FIELD_Y + FIELD_H * 0.35 + 60), FIELD_W, 56, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_overlay_title.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl_overlay_sub = _make_label(Vector2(0, FIELD_Y + FIELD_H * 0.35 + 160), FIELD_W, 36, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_overlay_sub.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl_overlay_title.visible = false
	lbl_overlay_sub.visible = false

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

func _lives_for(n: int) -> int:
	return max(3, n + 2)

func _start_level(n: int) -> void:
	level = clamp(n, 1, MAX_LEVEL)
	lives = _lives_for(level)
	captured = 0
	walls.clear()
	balls.clear()
	_init_grid()
	_spawn_balls(level)
	state = GameState.PLAYING
	intro_timer = 1.2
	queue_redraw()

func _init_grid() -> void:
	grid = []
	grid.resize(COLS)
	for x in COLS:
		var col := []
		col.resize(ROWS)
		for y in ROWS:
			col[y] = CellState.BORDER if (x == 0 or x == COLS - 1 or y == 0 or y == ROWS - 1) else CellState.EMPTY
		grid[x] = col
	play_total = (COLS - 2) * (ROWS - 2)

func _spawn_balls(count: int) -> void:
	for i in count:
		var px := randf_range(FIELD_X + CELL * 4, FIELD_X + (COLS - 4) * CELL)
		var py := randf_range(FIELD_Y + CELL * 4, FIELD_Y + (ROWS - 4) * CELL)
		var sp := BALL_SPEED * randf_range(0.92, 1.08)
		var sx := 1.0 if randi() % 2 == 0 else -1.0
		var sy := 1.0 if randi() % 2 == 0 else -1.0
		var inv := 1.0 / sqrt(2.0)
		balls.append({"pos": Vector2(px, py), "vel": Vector2(sx * sp * inv, sy * sp * inv)})

func _refresh_ui() -> void:
	if lbl_level == null:
		return
	lbl_level.text = "LEVEL %d" % level
	lbl_lives.text = "LIVES %d" % lives
	var pct := 0
	if play_total > 0:
		pct = int(round(float(captured) / float(play_total) * 100.0))
	lbl_pct.text = "%d%% / %d%%" % [pct, int(TARGET * 100)]
	lbl_orient.text = "VERTICAL" if orient_vertical else "HORIZONTAL"

func _solid_at(cx: int, cy: int) -> bool:
	if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
		return true
	var s = grid[cx][cy]
	return s == CellState.BORDER or s == CellState.WALL or s == CellState.CAPTURED or s == CellState.BUILDING

func _diag_rect(idx: int, c: Color, y: float) -> void:
	var r := ColorRect.new()
	r.color = c
	r.position = Vector2(idx * 270 + 5, y)
	r.size = Vector2(260, 100)
	add_child(r)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1080, 1500), Color(0.5, 0.9, 1.0, 1.0), true)
