extends Node2D

# JezzBall — mobile remake. Layout v2: controls at TOP (always reachable on
# any phone), saturated Win3-era palette, faster atoms, simplified atom sprite.

const COLS := 18
const ROWS := 25
const CELL := 60.0

const FIELD_X := 0.0
const HUD_H := 160.0
const CTRL_H := 130.0
const FIELD_Y := HUD_H + CTRL_H        # 290
const FIELD_W := COLS * CELL           # 1080
const FIELD_H := ROWS * CELL           # 1500

# Mostly-gray palette with small red/blue accents — closer to the original
# Win3 game's overall feel (gray field dominates; walls and captures are
# muted, not loud).
const COL_BG := Color(0.0, 0.0, 0.0)           # outer area / HUD background
const COL_FIELD := Color(0.80, 0.80, 0.80)     # field cell base color
const COL_GRID := Color(0.62, 0.62, 0.62)      # grid lines between cells
const COL_BORDER := Color(0.10, 0.10, 0.10)    # field outer border
const COL_WALL := Color(0.55, 0.10, 0.10)      # muted dark red completed wall
const COL_BUILDING := Color(0.78, 0.18, 0.18)  # slightly brighter red tip
const COL_CAPTURED := Color(0.42, 0.46, 0.62)  # muted blue-gray capture fill
const COL_BALL := Color(0.65, 0.12, 0.12)      # red atom (not bright)
const COL_BALL_DOT := Color(1.0, 1.0, 1.0)     # white highlight
const COL_BALL_OUTLINE := Color(0.25, 0.0, 0.0)
const COL_TEXT := Color(1.0, 1.0, 1.0)         # white text on black HUD
const COL_BTN := Color(0.18, 0.18, 0.18)       # dark button on black HUD
const COL_BTN_PRESSED := Color(0.32, 0.32, 0.32)
const COL_BTN_BORDER := Color(0.65, 0.65, 0.65)
const COL_BAR_BG := Color(0.18, 0.18, 0.18)
const COL_PREVIEW := Color(0.95, 0.95, 0.95, 0.5) # touch-preview line on field

const BALL_RADIUS := 22.0
const BALL_SPEED := 380.0
const WALL_SPEED := 9.0
const TARGET := 0.55
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
var btn_restart_flash := 0.0

var lbl_level: Label
var lbl_lives: Label
var lbl_pct: Label
var lbl_hint: Label
var lbl_restart: Label
var lbl_overlay_title: Label
var lbl_overlay_sub: Label
var overlay_box: ColorRect

# Single RESTART button. Wall direction is determined by SWIPE direction
# between touch-down and touch-up.
var rect_restart: Rect2

# Anchor for swipe gesture: on touch-down inside a valid empty cell, store
# pixel position + cell. On touch-up, the |dx| / |dy| from anchor decides
# orientation, then the wall commits at the original anchor cell.
var anchor_x := 0.0
var anchor_y := 0.0
var anchor_cx := -1
var anchor_cy := -1

func _ready() -> void:
	randomize()
	# Restart button on the right side of the control row.
	var pad := 12.0
	var ctrl_top := HUD_H + 8
	var ctrl_h := CTRL_H - 16
	var btn_w := 320.0
	rect_restart = Rect2(FIELD_W - btn_w - pad, ctrl_top, btn_w, ctrl_h)
	_build_ui()
	_start_level(1)

func _make_label(pos: Vector2, w: float, fs: int, halign: int = HORIZONTAL_ALIGNMENT_LEFT, fc: Color = COL_TEXT) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(w, fs * 1.6)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", fc)
	l.horizontal_alignment = halign
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l

func _build_ui() -> void:
	# HUD top row: LEVEL X | LIVES X
	lbl_level = _make_label(Vector2(20, 18), 500, 44)
	lbl_lives = _make_label(Vector2(FIELD_W - 520, 18), 500, 44, HORIZONTAL_ALIGNMENT_RIGHT)
	# HUD bottom row: percent text centered above progress bar
	lbl_pct = _make_label(Vector2(0, 78), FIELD_W, 32, HORIZONTAL_ALIGNMENT_CENTER)
	# Hint label + RESTART button.
	lbl_hint = _make_label(Vector2(20, HUD_H + 30), FIELD_W - rect_restart.size.x - 60, 28, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_hint.text = "Press a cell, swipe up/down for ↕  or  left/right for ↔"
	lbl_restart = _make_label(rect_restart.position + Vector2(0, 22), rect_restart.size.x, 40, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_restart.text = "RESTART"
	# Overlay backdrop + title/sub labels
	overlay_box = ColorRect.new()
	overlay_box.color = Color(0, 0, 0, 0.78)
	overlay_box.position = Vector2(0, FIELD_Y + FIELD_H * 0.30)
	overlay_box.size = Vector2(FIELD_W, 280)
	overlay_box.visible = false
	add_child(overlay_box)
	lbl_overlay_title = _make_label(Vector2(0, FIELD_Y + FIELD_H * 0.30 + 60), FIELD_W, 64, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1))
	lbl_overlay_sub = _make_label(Vector2(0, FIELD_Y + FIELD_H * 0.30 + 170), FIELD_W, 36, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1))
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
	intro_timer = 1.0
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
	if btn_restart_flash > 0.0:
		btn_restart_flash = max(0.0, btn_restart_flash - delta * 4.0)
	_refresh_ui()
	queue_redraw()

func _refresh_ui() -> void:
	if lbl_level == null:
		return
	lbl_level.text = "LEVEL %d" % level
	lbl_lives.text = "LIVES %d" % lives
	var pct := 0
	if play_total > 0:
		pct = int(round(float(_filled_count()) / float(play_total) * 100.0))
	lbl_pct.text = "%d %% / %d %%" % [pct, int(TARGET * 100)]
	var show_overlay := false
	var t_text := ""
	var s_text := ""
	if state == GameState.PLAYING and intro_timer > 0.0:
		show_overlay = true
		t_text = "LEVEL %d" % level
		s_text = "%d ball%s,  %d lives" % [level, "" if level == 1 else "s", lives]
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
	# Avoid the global sign(): its Variant overload breaks class-load on
	# some Android Godot 4.6 runtimes. Inline ternaries are safe.
	for b in balls:
		var pos: Vector2 = b["pos"]
		var vel: Vector2 = b["vel"]
		var sx := 1.0 if vel.x >= 0.0 else -1.0
		var sy := 1.0 if vel.y >= 0.0 else -1.0
		var nx := pos.x + vel.x * delta
		var probe_x := nx + sx * BALL_RADIUS
		var px_cell := int((probe_x - FIELD_X) / CELL)
		var py_cell := int((pos.y - FIELD_Y) / CELL)
		if _solid_at(px_cell, py_cell):
			vel.x = -vel.x
			nx = pos.x + vel.x * delta
		var ny := pos.y + vel.y * delta
		var probe_y := ny + sy * BALL_RADIUS
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
	# BUILDING cells are NOT solid: balls pass into them so _check_wall_hits
	# can destroy the wall and dock a life. Only BORDER/WALL/CAPTURED bounce.
	return s == CellState.BORDER or s == CellState.WALL or s == CellState.CAPTURED

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

func _filled_count() -> int:
	# Cells that count as "yours": completed walls + captured regions.
	var n := 0
	for x in range(1, COLS - 1):
		for y in range(1, ROWS - 1):
			var s = grid[x][y]
			if s == CellState.CAPTURED or s == CellState.WALL:
				n += 1
	return n

func _check_win() -> void:
	if float(_filled_count()) / float(play_total) >= TARGET:
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

	if pressed:
		# Overlays consume the tap.
		if state == GameState.LEVEL_WIN:
			var nxt := level + 1
			if nxt > MAX_LEVEL:
				nxt = 1
			_start_level(nxt)
			return
		if state == GameState.LEVEL_LOSE:
			_start_level(level)
			return
		if rect_restart.has_point(p):
			btn_restart_flash = 0.25
			_start_level(level)
			anchor_cx = -1
			return
		# Field tap → record anchor; wall commits on release.
		anchor_cx = -1
		if p.y >= FIELD_Y and p.y < FIELD_Y + FIELD_H and p.x >= FIELD_X and p.x < FIELD_X + FIELD_W:
			var cx := int((p.x - FIELD_X) / CELL)
			var cy := int((p.y - FIELD_Y) / CELL)
			if cx >= 1 and cx < COLS - 1 and cy >= 1 and cy < ROWS - 1 and grid[cx][cy] == CellState.EMPTY:
				anchor_x = p.x
				anchor_y = p.y
				anchor_cx = cx
				anchor_cy = cy
		return

	# RELEASED.
	if anchor_cx < 0:
		return
	var dx_signed := p.x - anchor_x
	var dy_signed := p.y - anchor_y
	var ax := dx_signed if dx_signed >= 0.0 else -dx_signed
	var ay := dy_signed if dy_signed >= 0.0 else -dy_signed
	# Need a clear swipe (>= 25 px) on one axis to flip orientation.
	# Tap with no swipe keeps current orient_vertical (so consecutive taps
	# stay in the same direction without re-swiping).
	if ax >= 25.0 or ay >= 25.0:
		orient_vertical = ay > ax
	if grid[anchor_cx][anchor_cy] == CellState.EMPTY:
		_start_wall(anchor_cx, anchor_cy)
	anchor_cx = -1

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
	# Bottom edge below the field is the same gray as the HUD background.
	draw_rect(Rect2(0, 0, FIELD_W, 1920), COL_BG, true)
	_draw_hud_chrome()
	_draw_controls()
	_draw_field()

func _draw_hud_chrome() -> void:
	# Progress bar inside HUD.
	var bar_w := FIELD_W - 60.0
	var bar_x := 30.0
	var bar_y := 124.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, 22), COL_BAR_BG, true)
	var fill := 0.0
	if play_total > 0:
		fill = bar_w * float(_filled_count()) / float(play_total)
	draw_rect(Rect2(bar_x, bar_y, fill, 22), COL_CAPTURED, true)
	var target_x := bar_x + bar_w * TARGET
	draw_line(Vector2(target_x, bar_y - 6), Vector2(target_x, bar_y + 28), COL_TEXT, 3)

func _draw_controls() -> void:
	# Restart button only — orientation chosen by tap position inside the cell.
	var rcol := COL_BTN_PRESSED if btn_restart_flash > 0.0 else COL_BTN
	draw_rect(rect_restart, rcol, true)
	draw_rect(rect_restart, COL_BTN_BORDER, false, 4)

func _draw_field() -> void:
	# Field background — uniform light gray.
	draw_rect(Rect2(FIELD_X, FIELD_Y, FIELD_W, FIELD_H), COL_FIELD, true)
	# Subtle grid lines between cells (matches the original screenshot look).
	for x in range(1, COLS):
		var lx := FIELD_X + x * CELL
		draw_line(Vector2(lx, FIELD_Y), Vector2(lx, FIELD_Y + FIELD_H), COL_GRID, 1.0)
	for y in range(1, ROWS):
		var ly := FIELD_Y + y * CELL
		draw_line(Vector2(FIELD_X, ly), Vector2(FIELD_X + FIELD_W, ly), COL_GRID, 1.0)
	# Captured cells (solid saturated blue).
	for x in range(1, COLS - 1):
		for y in range(1, ROWS - 1):
			if grid[x][y] == CellState.CAPTURED:
				draw_rect(Rect2(FIELD_X + x * CELL, FIELD_Y + y * CELL, CELL, CELL), COL_CAPTURED, true)
	# Borders + completed walls (red) + building cells (blue growing tip).
	for x in COLS:
		for y in ROWS:
			var s = grid[x][y]
			if s == CellState.BORDER:
				draw_rect(Rect2(FIELD_X + x * CELL, FIELD_Y + y * CELL, CELL, CELL), COL_BORDER, true)
			elif s == CellState.WALL:
				draw_rect(Rect2(FIELD_X + x * CELL, FIELD_Y + y * CELL, CELL, CELL), COL_WALL, true)
			elif s == CellState.BUILDING:
				draw_rect(Rect2(FIELD_X + x * CELL, FIELD_Y + y * CELL, CELL, CELL), COL_BUILDING, true)
	# Atoms — bigger now (BALL_RADIUS=22), red disc with white highlight.
	for b in balls:
		var p: Vector2 = b["pos"]
		draw_circle(p, BALL_RADIUS + 2, COL_BALL_OUTLINE)
		draw_circle(p, BALL_RADIUS, COL_BALL)
		draw_circle(p + Vector2(-BALL_RADIUS * 0.35, -BALL_RADIUS * 0.35), BALL_RADIUS * 0.30, COL_BALL_DOT)
	# Swipe preview while finger is down on a valid cell — semi-transparent
	# guide line through the anchor cell in the orientation the wall WILL take.
	if anchor_cx >= 0:
		var ax_px := FIELD_X + anchor_cx * CELL + CELL * 0.5
		var ay_px := FIELD_Y + anchor_cy * CELL + CELL * 0.5
		if orient_vertical:
			draw_line(Vector2(ax_px, FIELD_Y + CELL), Vector2(ax_px, FIELD_Y + FIELD_H - CELL), COL_PREVIEW, 4)
		else:
			draw_line(Vector2(FIELD_X + CELL, ay_px), Vector2(FIELD_X + FIELD_W - CELL, ay_px), COL_PREVIEW, 4)
		draw_circle(Vector2(ax_px, ay_px), 8, Color(1, 1, 1, 0.6))
