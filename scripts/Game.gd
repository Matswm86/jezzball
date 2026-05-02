extends Node2D

# DIAGNOSTIC v4 — full declarations, minimal _ready
# All const/enum/var declarations from the real game are present, but _ready
# only runs the marker code. If markers still appear, declarations are fine
# and the bug is somewhere in the function bodies we'll add back next.

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
	_diag_rect(0, Color(1, 0, 1), 1700)   # MAGENTA build tag for v4
	_diag_rect(0, Color(1, 0, 0), 1820)   # RED — _ready entered
	_diag_rect(1, Color(0, 1, 0), 1820)   # GREEN
	_diag_rect(2, Color(0, 0, 1), 1820)   # BLUE
	_diag_rect(3, Color(1, 1, 0), 1820)   # YELLOW

func _diag_rect(idx: int, c: Color, y: float) -> void:
	var r := ColorRect.new()
	r.color = c
	r.position = Vector2(idx * 270 + 5, y)
	r.size = Vector2(260, 100)
	add_child(r)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1080, 1500), Color(0.5, 0.9, 1.0, 1.0), true)
