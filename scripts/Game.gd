extends Node2D

# DIAGNOSTIC v10 — _update_balls confirmed offender in v9. Theory: the implicit
# sign(vel.x) Variant overload fails to resolve at class-load time on this runtime.
# Replacing both sign() calls with explicit float ternaries. Markers reappearing
# confirms sign() was the offender; if still white, problem is elsewhere in the body.

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
	_diag_rect(0, Color(1, 0, 1), 1580)   # MAGENTA build tag (v10)
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

func _advance_walls(delta: float) -> void:
	for w in walls:
		for head_key in ["a", "b"]:
			if w[head_key + "_done"]:
				continue
			var prev_int := int(w[head_key])
			w[head_key] += WALL_SPEED * delta
			var new_int := int(w[head_key])
			for i in range(prev_int + 1, new_int + 1):
				var c: Vector2i = _wall_cell(w, head_key, i)
				if c.x < 1 or c.x > COLS - 2 or c.y < 1 or c.y > ROWS - 2:
					w[head_key + "_done"] = true
					break
				if grid[c.x][c.y] != CellState.EMPTY:
					w[head_key + "_done"] = true
					break
				grid[c.x][c.y] = CellState.BUILDING
				w["cells"].append(c)

func _wall_cell(w: Dictionary, head_key: String, dist: int) -> Vector2i:
	var o: Vector2i = w["origin"]
	if w["orient"] == "V":
		return Vector2i(o.x, o.y - dist) if head_key == "a" else Vector2i(o.x, o.y + dist)
	return Vector2i(o.x - dist, o.y) if head_key == "a" else Vector2i(o.x + dist, o.y)

func _flood(sx: int, sy: int, visited: Array) -> Array:
	var region := []
	var stack: Array = [Vector2i(sx, sy)]
	while stack.size() > 0:
		var c: Vector2i = stack.pop_back()
		if c.x < 1 or c.x >= COLS - 1 or c.y < 1 or c.y >= ROWS - 1:
			continue
		if visited[c.x][c.y]:
			continue
		if grid[c.x][c.y] != CellState.EMPTY:
			continue
		visited[c.x][c.y] = true
		region.append(c)
		stack.append(Vector2i(c.x + 1, c.y))
		stack.append(Vector2i(c.x - 1, c.y))
		stack.append(Vector2i(c.x, c.y + 1))
		stack.append(Vector2i(c.x, c.y - 1))
	return region

func _update_balls(delta: float) -> void:
	for b in balls:
		var pos: Vector2 = b["pos"]
		var vel: Vector2 = b["vel"]
		var sign_x := 1.0 if vel.x >= 0.0 else -1.0
		var sign_y := 1.0 if vel.y >= 0.0 else -1.0
		var nx := pos.x + vel.x * delta
		var probe_x := nx + sign_x * BALL_RADIUS
		var px_cell := int((probe_x - FIELD_X) / CELL)
		var py_cell := int((pos.y - FIELD_Y) / CELL)
		if _solid_at(px_cell, py_cell):
			vel.x = -vel.x
			nx = pos.x + vel.x * delta
		var ny := pos.y + vel.y * delta
		var probe_y := ny + sign_y * BALL_RADIUS
		var qx_cell := int((pos.x - FIELD_X) / CELL)
		var qy_cell := int((probe_y - FIELD_Y) / CELL)
		if _solid_at(qx_cell, qy_cell):
			vel.y = -vel.y
			ny = pos.y + vel.y * delta
		b["pos"] = Vector2(nx, ny)
		b["vel"] = vel

func _diag_rect(idx: int, c: Color, y: float) -> void:
	var r := ColorRect.new()
	r.color = c
	r.position = Vector2(idx * 270 + 5, y)
	r.size = Vector2(260, 100)
	add_child(r)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1080, 1500), Color(0.5, 0.9, 1.0, 1.0), true)
