extends Node2D

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

const COL_BG := Color(0.827, 0.827, 0.827)         # #D3D3D3 lightGray (Win3 face)
const COL_FIELD := Color(0.827, 0.827, 0.827)      # field interior matches bg
const COL_BORDER := Color(0.663, 0.663, 0.663)     # #A9A9A9 darkGray border
const COL_WALL := Color(0.722, 0.396, 0.400)       # #B86566 fadedRed completed wall
const COL_BUILDING := Color(0.467, 0.184, 0.196)   # darker red while growing
const COL_CAPTURED := Color(0.506, 0.529, 0.871)   # #8187DE fadedBlue capture fill
const COL_BALL := Color(0.722, 0.396, 0.400)       # red base
const COL_BALL_PATTERN := Color(1.0, 1.0, 1.0)     # white checker spot
const COL_BALL_OUTLINE := Color(0.4, 0.18, 0.18)   # dark-red outline
const COL_TEXT := Color(0.0, 0.0, 0.0)             # black ink on light gray
const COL_BTN := Color(0.95, 0.95, 0.95)
const COL_BTN_BORDER := Color(0.4, 0.4, 0.4)
const COL_BAR_BG := Color(0.7, 0.7, 0.7)
const COL_BAR_FILL := Color(0.506, 0.529, 0.871)   # progress bar uses fadedBlue too

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
	_diag_rect(0, Color(1, 0, 0))   # RED  — _ready entered
	randomize()
	_diag_rect(1, Color(0, 1, 0))   # GREEN — randomize ok
	_build_ui()
	_diag_rect(2, Color(0, 0, 1))   # BLUE  — _build_ui ok
	_start_level(1)
	_diag_rect(3, Color(1, 1, 0))   # YELLOW — _start_level ok

func _diag_rect(idx: int, c: Color) -> void:
	var r := ColorRect.new()
	r.color = c
	r.position = Vector2(idx * 270, 1820)
	r.size = Vector2(260, 100)
	add_child(r)

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

func _process(delta: float) -> void:
	if state == GameState.PLAYING:
		if intro_timer > 0.0:
			intro_timer -= delta
		else:
			_advance_walls(delta)
			_update_balls(delta)
			_check_wall_hits()
			_check_win()
	_refresh_ui()
	queue_redraw()

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
	var show_overlay := false
	var t_text := ""
	var s_text := ""
	if state == GameState.PLAYING and intro_timer > 0.0:
		show_overlay = true
		t_text = "LEVEL %d" % level
		s_text = "%d ball%s   %d lives" % [level, "" if level == 1 else "s", lives]
	elif state == GameState.LEVEL_WIN:
		show_overlay = true
		t_text = "LEVEL CLEARED"
		s_text = "Tap to advance"
	elif state == GameState.LEVEL_LOSE:
		show_overlay = true
		t_text = "OUT OF LIVES"
		s_text = "Tap to retry"
	overlay_box.visible = show_overlay
	lbl_overlay_title.visible = show_overlay
	lbl_overlay_sub.visible = show_overlay
	if show_overlay:
		lbl_overlay_title.text = t_text
		lbl_overlay_sub.text = s_text

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
	var done := []
	for w in walls:
		if w["a_done"] and w["b_done"]:
			done.append(w)
	for w in done:
		_complete_wall(w)
		walls.erase(w)

func _wall_cell(w: Dictionary, head_key: String, dist: int) -> Vector2i:
	var o: Vector2i = w["origin"]
	if w["orient"] == "V":
		return Vector2i(o.x, o.y - dist) if head_key == "a" else Vector2i(o.x, o.y + dist)
	return Vector2i(o.x - dist, o.y) if head_key == "a" else Vector2i(o.x + dist, o.y)

func _complete_wall(w: Dictionary) -> void:
	for c in w["cells"]:
		grid[c.x][c.y] = CellState.WALL
	_flood_capture()

func _flood_capture() -> void:
	var visited := []
	visited.resize(COLS)
	for x in COLS:
		var row := []
		row.resize(ROWS)
		row.fill(false)
		visited[x] = row
	for x in range(1, COLS - 1):
		for y in range(1, ROWS - 1):
			if grid[x][y] == CellState.EMPTY and not visited[x][y]:
				var region := _flood(x, y, visited)
				if not _region_has_ball(region):
					for c in region:
						grid[c.x][c.y] = CellState.CAPTURED
						captured += 1

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

func _region_has_ball(region: Array) -> bool:
	for b in balls:
		var p: Vector2 = b["pos"]
		var cx := int((p.x - FIELD_X) / CELL)
		var cy := int((p.y - FIELD_Y) / CELL)
		for c in region:
			if c.x == cx and c.y == cy:
				return true
	return false

func _update_balls(delta: float) -> void:
	for b in balls:
		var pos: Vector2 = b["pos"]
		var vel: Vector2 = b["vel"]
		var nx := pos.x + vel.x * delta
		var probe_x := nx + sign(vel.x) * BALL_RADIUS
		var px_cell := int((probe_x - FIELD_X) / CELL)
		var py_cell := int((pos.y - FIELD_Y) / CELL)
		if _solid_at(px_cell, py_cell):
			vel.x = -vel.x
			nx = pos.x + vel.x * delta
		var ny := pos.y + vel.y * delta
		var probe_y := ny + sign(vel.y) * BALL_RADIUS
		var qx_cell := int((pos.x - FIELD_X) / CELL)
		var qy_cell := int((probe_y - FIELD_Y) / CELL)
		if _solid_at(qx_cell, qy_cell):
			vel.y = -vel.y
			ny = pos.y + vel.y * delta
		b["pos"] = Vector2(nx, ny)
		b["vel"] = vel

func _solid_at(cx: int, cy: int) -> bool:
	if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
		return true
	var s = grid[cx][cy]
	return s == CellState.BORDER or s == CellState.WALL or s == CellState.CAPTURED or s == CellState.BUILDING

func _check_wall_hits() -> void:
	var to_destroy := []
	for w in walls:
		for c in w["cells"]:
			if _ball_overlaps_cell(c):
				to_destroy.append(w)
				break
	for w in to_destroy:
		if walls.has(w):
			_destroy_wall(w)
			lives -= 1
			if lives <= 0:
				state = GameState.LEVEL_LOSE
				return

func _ball_overlaps_cell(c: Vector2i) -> bool:
	var cx_px := FIELD_X + c.x * CELL + CELL * 0.5
	var cy_px := FIELD_Y + c.y * CELL + CELL * 0.5
	for b in balls:
		var p: Vector2 = b["pos"]
		if abs(p.x - cx_px) > CELL * 0.5 + BALL_RADIUS:
			continue
		if abs(p.y - cy_px) > CELL * 0.5 + BALL_RADIUS:
			continue
		return true
	return false

func _destroy_wall(w: Dictionary) -> void:
	for c in w["cells"]:
		if grid[c.x][c.y] == CellState.BUILDING:
			grid[c.x][c.y] = CellState.EMPTY
	walls.erase(w)

func _check_win() -> void:
	if float(captured) / float(play_total) >= TARGET:
		state = GameState.LEVEL_WIN

func _input(event: InputEvent) -> void:
	var pressed := false
	var p := Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = event.pressed
		p = event.position
	elif event is InputEventMouseButton:
		pressed = event.pressed
		p = event.position
	else:
		return
	if not pressed:
		return

	if state == GameState.LEVEL_WIN:
		var nxt := level + 1
		if nxt > MAX_LEVEL:
			nxt = 1
		_start_level(nxt)
		return
	if state == GameState.LEVEL_LOSE:
		_start_level(level)
		return

	if p.y >= CTRL_Y:
		if p.x < FIELD_W * 0.5:
			orient_vertical = !orient_vertical
		else:
			_start_level(level)
		queue_redraw()
		return
	if p.y >= FIELD_Y and p.y < FIELD_Y + FIELD_H and p.x >= FIELD_X and p.x < FIELD_X + FIELD_W:
		var cx := int((p.x - FIELD_X) / CELL)
		var cy := int((p.y - FIELD_Y) / CELL)
		if cx >= 1 and cx < COLS - 1 and cy >= 1 and cy < ROWS - 1:
			if grid[cx][cy] == CellState.EMPTY:
				_start_wall(cx, cy)

func _start_wall(cx: int, cy: int) -> void:
	var w := {
		"origin": Vector2i(cx, cy),
		"orient": "V" if orient_vertical else "H",
		"a": 0.0,
		"b": 0.0,
		"a_done": false,
		"b_done": false,
		"cells": [Vector2i(cx, cy)],
	}
	grid[cx][cy] = CellState.BUILDING
	walls.append(w)

func _draw() -> void:
	draw_rect(Rect2(0, 0, FIELD_W, 1920), COL_BG, true)
	_draw_hud()
	_draw_field()
	_draw_controls()

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, FIELD_W, HUD_H), COL_BG, true)
	draw_rect(Rect2(0, HUD_H - 4, FIELD_W, 4), COL_BORDER, true)
	var bar_w := FIELD_W - 40
	var bar_x := 20.0
	var bar_y := 130.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, 16), COL_BAR_BG, true)
	var fill := 0.0
	if play_total > 0:
		fill = bar_w * float(captured) / float(play_total)
	draw_rect(Rect2(bar_x, bar_y, fill, 16), COL_BAR_FILL, true)
	var target_x := bar_x + bar_w * TARGET
	draw_line(Vector2(target_x, bar_y - 4), Vector2(target_x, bar_y + 20), COL_TEXT, 2)

func _draw_field() -> void:
	for x in range(1, COLS - 1):
		for y in range(1, ROWS - 1):
			var s = grid[x][y]
			if s == CellState.CAPTURED:
				draw_rect(Rect2(FIELD_X + x * CELL, FIELD_Y + y * CELL, CELL, CELL), COL_CAPTURED, true)
	for x in COLS:
		for y in ROWS:
			var s = grid[x][y]
			if s == CellState.BORDER or s == CellState.WALL:
				draw_rect(Rect2(FIELD_X + x * CELL, FIELD_Y + y * CELL, CELL, CELL), COL_WALL, true)
			elif s == CellState.BUILDING:
				draw_rect(Rect2(FIELD_X + x * CELL, FIELD_Y + y * CELL, CELL, CELL), COL_BUILDING, true)
	for b in balls:
		var p: Vector2 = b["pos"]
		draw_circle(p, BALL_RADIUS + 1, COL_BALL_OUTLINE)
		draw_circle(p, BALL_RADIUS, COL_BALL)
		# 4-pole white checker spots — red+white alternation cue from original atom.
		var r2 := BALL_RADIUS * 0.45
		draw_circle(p + Vector2(-r2, 0), 3, COL_BALL_PATTERN)
		draw_circle(p + Vector2(r2, 0), 3, COL_BALL_PATTERN)
		draw_circle(p + Vector2(0, -r2), 3, COL_BALL_PATTERN)
		draw_circle(p + Vector2(0, r2), 3, COL_BALL_PATTERN)

func _draw_controls() -> void:
	draw_rect(Rect2(0, CTRL_Y, FIELD_W, CTRL_H), COL_BG, true)
	draw_rect(Rect2(0, CTRL_Y, FIELD_W, 4), COL_BORDER, true)
	var btn_w := FIELD_W * 0.5 - 20
	draw_rect(Rect2(10, CTRL_Y + 10, btn_w, CTRL_H - 20), COL_BTN, true)
	draw_rect(Rect2(10, CTRL_Y + 10, btn_w, CTRL_H - 20), COL_BTN_BORDER, false, 3)
	draw_rect(Rect2(FIELD_W * 0.5 + 10, CTRL_Y + 10, btn_w, CTRL_H - 20), COL_BTN, true)
	draw_rect(Rect2(FIELD_W * 0.5 + 10, CTRL_Y + 10, btn_w, CTRL_H - 20), COL_BTN_BORDER, false, 3)
