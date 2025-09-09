extends Node2D

enum Phase { PLAYER_TURN, ENEMY_TURN, WIN, LOSE }

@onready var cam: Camera2D   = $"Camera2D"
@onready var bg: Sprite2D    = $"Background"
@onready var player: Player  = $"Player"
@onready var z1: Enemy       = $"z1"
@onready var z2: Enemy       = $"z2"
@onready var boss: Enemy     = $"boss"

# Player bases
const P_BASE_HP   := 60
const P_BASE_ATK  := 20
const P_BASE_DEF  := 5

# Enemy bases (Stage 1 reference)
const E_BASE_HP  := 40
const E_BASE_ATK := 10
const E_BASE_DEF := 2

var current_enemy: Enemy
var stage := 0
var guard_active := false
var run_timer: Timer

# UI
var ui: Control
var info_label: Label
var player_hp: Label
var enemy_hp: Label
var lbl_timer: Label
var lbl_stage: Label
var btn_attack: Button
var btn_guard: Button
var btn_heal: Button
var result_lbl: Label
var btn_restart: Button
var result_overlay: Control

var phase := Phase.PLAYER_TURN

func _ready() -> void:
	cam.enabled = true
	cam.make_current()

	_build_ui()
	_build_timer()

	player._on_revert(); z1._on_revert(); z2._on_revert(); boss._on_revert()

	_start_run()

func _build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(ui)

	# Top-left labels
	player_hp = Label.new(); player_hp.position = Vector2(16, 16)
	enemy_hp  = Label.new(); enemy_hp.position  = Vector2(16, 40)
	lbl_stage = Label.new(); lbl_stage.position = Vector2(16, 64)
	lbl_timer = Label.new(); lbl_timer.position = Vector2(1000, 16)
	ui.add_child(player_hp); ui.add_child(enemy_hp); ui.add_child(lbl_stage); ui.add_child(lbl_timer)

	# Top-center info
	info_label = Label.new()
	info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.position = Vector2(0, 16)
	ui.add_child(info_label)

	var cmd := HBoxContainer.new()
	cmd.anchor_left = 0.5; cmd.anchor_right = 0.5
	cmd.anchor_top  = 1.0; cmd.anchor_bottom = 1.0
	cmd.offset_top = -48; cmd.offset_left = -180; cmd.offset_right = 180
	cmd.add_theme_constant_override("separation", 16)
	ui.add_child(cmd)

	btn_attack = Button.new(); btn_attack.text = "Attack"; cmd.add_child(btn_attack)
	btn_guard  = Button.new(); btn_guard.text  = "Guard";  cmd.add_child(btn_guard)
	btn_heal   = Button.new(); btn_heal.text   = "Heal";   cmd.add_child(btn_heal)

	btn_attack.pressed.connect(_on_attack)
	btn_guard.pressed.connect(_on_guard)
	btn_heal.pressed.connect(_on_heal)

	# Centered result overlay (works while paused)
	result_overlay = VBoxContainer.new()
	result_overlay.anchor_left = 0.5; result_overlay.anchor_right = 0.5
	result_overlay.anchor_top  = 0.5; result_overlay.anchor_bottom = 0.5
	result_overlay.offset_left = -320; result_overlay.offset_right = 320
	result_overlay.offset_top  = -140; result_overlay.offset_bottom = 140
	result_overlay.alignment = BoxContainer.ALIGNMENT_CENTER
	result_overlay.visible = false
	result_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	cl.add_child(result_overlay)

	result_lbl = Label.new()
	var ls := LabelSettings.new(); ls.font_size = 96
	result_lbl.label_settings = ls
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_overlay.add_child(result_lbl)

	btn_restart = Button.new()
	btn_restart.text = "Restart"
	btn_restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_restart.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	btn_restart.pressed.connect(_on_restart_pressed)
	result_overlay.add_child(btn_restart)

func _build_timer() -> void:
	run_timer = Timer.new()
	run_timer.one_shot = true
	add_child(run_timer)
	run_timer.timeout.connect(_on_run_timer_timeout)

func _start_run() -> void:
	run_timer.wait_time = 90.00
	run_timer.start()
	_start_stage(1)

func _start_stage(s: int) -> void:
	stage = s

	if s == 1:
		current_enemy = z1
	elif s == 2:
		current_enemy = z2
	else:
		current_enemy = boss

	z1.visible = (current_enemy == z1)
	z2.visible = (current_enemy == z2)
	boss.visible = (current_enemy == boss)

	lbl_stage.text = "Stage %d" % s

	_apply_player_stage_stats(s)
	_apply_enemy_stage_stats(s)

	phase = Phase.PLAYER_TURN
	guard_active = false
	_update_labels("A wild %s appears!" % current_enemy.display_name)

	var ed := _enemy_stage_values(s)
	info_label.text = "Stage {s} — You HP {php}/{pmax} ATK {patk} DEF {pdef} | Enemy HP {ehp} ATK {eatk} DEF {edef}".format({
		"s": s,
		"php": player.hp, "pmax": player.max_hp, "patk": player.atk, "pdef": player.defense,
		"ehp": ed["hp"],  "eatk": ed["atk"],    "edef": ed["def"],
	})


func _advance_or_win() -> void:
	if stage < 3:
		_start_stage(stage + 1)
	else:
		_win()

func _process(_dt: float) -> void:
	if run_timer != null and not run_timer.is_stopped():
		var t := int(ceil(run_timer.time_left))
		var m := t / 60
		var s := t % 60
		lbl_timer.text = "Timer: %02d:%02d" % [m, s]

func _update_labels(extra := "") -> void:
	player_hp.text = "Player HP {hp}/{max} (ATK {atk}, DEF {def})".format({
		"hp": player.hp, "max": player.max_hp, "atk": player.atk, "def": player.defense
	})
	enemy_hp.text  = "{name} HP {hp}/{max} (ATK {atk}, DEF {def})".format({
		"name": current_enemy.display_name,
		"hp": current_enemy.hp, "max": current_enemy.max_hp,
		"atk": current_enemy.atk, "def": current_enemy.defense
	})
	if extra != "":
		info_label.text = extra


func _on_attack() -> void:
	if phase != Phase.PLAYER_TURN: return
	player.swing()
	current_enemy.take_damage(player.atk)
	_update_labels("You attack!")
	if current_enemy.is_dead():
		await get_tree().create_timer(0.35).timeout
		_advance_or_win()
		return
	await get_tree().create_timer(0.25).timeout
	phase = Phase.ENEMY_TURN
	_enemy_act()

func _on_guard() -> void:
	if phase != Phase.PLAYER_TURN: return
	player.guard()
	guard_active = true
	_update_labels("You guard (halve next hit).")
	await get_tree().create_timer(0.25).timeout
	phase = Phase.ENEMY_TURN
	_enemy_act()

func _on_heal() -> void:
	if phase != Phase.PLAYER_TURN: return
	player.heal_small()
	_update_labels("You patch up.")
	await get_tree().create_timer(0.25).timeout
	phase = Phase.ENEMY_TURN
	_enemy_act()

func _enemy_act() -> void:
	if phase != Phase.ENEMY_TURN or current_enemy == null: return

	var do_attack := randf() < 0.8 or player.hp <= 15
	if do_attack:
		current_enemy.swing()
		var dmg := current_enemy.atk
		if guard_active:
			dmg = int(ceil(dmg * 0.5))
		player.apply_damage(dmg)
		guard_active = false
		_update_labels("%s hits you!" % current_enemy.display_name)
	else:
		current_enemy.guard()
		_update_labels("%s is guarding…" % current_enemy.display_name)
		current_enemy.defense += 999
		await get_tree().create_timer(0.1).timeout
		current_enemy.defense -= 999

	_update_labels()
	if player.hp <= 0:
		_lose("Died.")
		return

	phase = Phase.PLAYER_TURN



func _on_run_timer_timeout() -> void:
	if !(stage == 3 and current_enemy != null and current_enemy.is_dead()):
		_fail_time()

func _win() -> void:
	run_timer.stop()
	_show_result(true, "YOU WIN")

func _fail_time() -> void:
	run_timer.stop()
	_show_result(false, "FAILED")

func _lose(reason: String) -> void:
	run_timer.stop()
	_show_result(false, "YOU LOSE\n" + reason)

func _show_result(_w: bool, text: String) -> void:
	result_lbl.text = text
	result_overlay.visible = true
	get_tree().paused = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _apply_player_stage_stats(s: int) -> void:
	var mult_hp  := 1.0
	var mult_atk := 1.0
	var mult_def := 1.0
	match s:
		1:
			mult_hp = 1.0;  mult_atk = 1.0;  mult_def = 1.0
		2:
			mult_hp = 1.15; mult_atk = 1.50; mult_def = 1.25
		3:
			mult_hp = 1.30; mult_atk = 1.80; mult_def = 1.40
		_:
			mult_hp = 1.30; mult_atk = 1.80; mult_def = 1.40

	var new_max_hp := int(round(P_BASE_HP  * mult_hp))
	var new_atk    := int(round(P_BASE_ATK * mult_atk))
	var new_def    := int(round(P_BASE_DEF * mult_def))

	player.set_stats(new_max_hp, new_atk, new_def, true, false)

func _enemy_stage_values(s: int) -> Dictionary:
	var mult_hp: float
	var mult_atk: float
	var mult_def: float
	match s:
		1:
			mult_hp = 1.0;  mult_atk = 1.0;  mult_def = 1.0
		2:
			mult_hp = 2.75; mult_atk = 3.00; mult_def = 3.00
		3:
			mult_hp = 3.10; mult_atk = 3.15; mult_def = 3.15
		_:
			mult_hp = 3.10; mult_atk = 3.15; mult_def = 3.15
	return {
		"hp":  int(round(E_BASE_HP  * mult_hp)),  # 40, 46, 66
		"atk": int(round(E_BASE_ATK * mult_atk)), # 10, 15, 20
		"def": int(round(E_BASE_DEF * mult_def)), #  2,  3,  4
	}

func _apply_enemy_stage_stats(s: int) -> void:
	var ed := _enemy_stage_values(s)
	current_enemy.set_stats(ed["hp"], ed["atk"], ed["def"])
