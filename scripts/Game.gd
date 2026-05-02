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

const COL_BG := Color("000000")
const COL_BORDER := Color("00aaaa")
const COL_WALL := Color("00aaaa")
const COL_BUILDING := Color("00ffff")
const COL_CAPTURED := Color("000080")
const COL_BALL := Color("ff5555")
const COL_BALL_OUTLINE := Color("aa0000")
const COL_TEXT := Color("ffffff")
const COL_BTN := Color("002040")
const COL_BTN_BORDER := Color("00aaaa")

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

func _ready() -> void:
	randomize()
	_start_level(1)

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
	queue_redraw()

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
	if intro_timer > 0.0 and state == GameState.PLAYING:
		_draw_overlay("LEVEL %d" % level, "%d ball%s   %d lives" % [level, "" if level == 1 else "s", lives])
	elif state == GameState.LEVEL_WIN:
		_draw_overlay("LEVEL CLEARED", "Tap to advance")
	elif state == GameState.LEVEL_LOSE:
		_draw_overlay("OUT OF LIVES", "Tap to retry")

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, FIELD_W, HUD_H), COL_BG, true)
	draw_rect(Rect2(0, HUD_H - 4, FIELD_W, 4), COL_BORDER, true)
	var f := ThemeDB.fallback_font
	var fs := 36
	var pct := int(round(float(captured) / float(play_total) * 100.0))
	draw_string(f, Vector2(20, 60), "LEVEL %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_TEXT)
	draw_string(f, Vector2(20, 110), "LIVES %d" % lives, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_TEXT)
	var pct_text := "%d%% / %d%%" % [pct, int(TARGET * 100)]
	draw_string(f, Vector2(FIELD_W - 380, 60), pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_TEXT)
	var bar_w := FIELD_W - 40
	var bar_x := 20.0
	var bar_y := 130.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, 16), Color("002020"), true)
	var fill := bar_w * float(captured) / float(play_total)
	draw_rect(Rect2(bar_x, bar_y, fill, 16), COL_BORDER, true)
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
		draw_circle(p, BALL_RADIUS - 1, COL_BALL)
		draw_circle(p + Vector2(-4, -4), 3, Color("ffaaaa"))

func _draw_controls() -> void:
	draw_rect(Rect2(0, CTRL_Y, FIELD_W, CTRL_H), COL_BG, true)
	draw_rect(Rect2(0, CTRL_Y, FIELD_W, 4), COL_BORDER, true)
	var f := ThemeDB.fallback_font
	var btn_w := FIELD_W * 0.5 - 20
	draw_rect(Rect2(10, CTRL_Y + 10, btn_w, CTRL_H - 20), COL_BTN, true)
	draw_rect(Rect2(10, CTRL_Y + 10, btn_w, CTRL_H - 20), COL_BTN_BORDER, false, 3)
	var label := "VERTICAL" if orient_vertical else "HORIZONTAL"
	draw_string(f, Vector2(10, CTRL_Y + 50), label, HORIZONTAL_ALIGNMENT_CENTER, btn_w, 30, COL_TEXT)
	draw_rect(Rect2(FIELD_W * 0.5 + 10, CTRL_Y + 10, btn_w, CTRL_H - 20), COL_BTN, true)
	draw_rect(Rect2(FIELD_W * 0.5 + 10, CTRL_Y + 10, btn_w, CTRL_H - 20), COL_BTN_BORDER, false, 3)
	draw_string(f, Vector2(FIELD_W * 0.5 + 10, CTRL_Y + 50), "RESTART", HORIZONTAL_ALIGNMENT_CENTER, btn_w, 30, COL_TEXT)

func _draw_overlay(title: String, sub: String) -> void:
	var oy := FIELD_Y + FIELD_H * 0.35
	draw_rect(Rect2(0, oy, FIELD_W, 280), Color(0, 0, 0, 0.85), true)
	draw_rect(Rect2(0, oy, FIELD_W, 280), COL_BORDER, false, 4)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(0, oy + 100), title, HORIZONTAL_ALIGNMENT_CENTER, FIELD_W, 56, COL_TEXT)
	draw_string(f, Vector2(0, oy + 190), sub, HORIZONTAL_ALIGNMENT_CENTER, FIELD_W, 36, COL_TEXT)
