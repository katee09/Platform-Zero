extends Node2D
const MULT := [1.0, 2.0, 4.0]
enum Phase { EXPLORE, PLAYER_TURN, ENEMY_TURN, WIN, LOSE }

# 👉 These nodes must exist in the scene tree (see steps below)
@export var player_start: Vector2     = Vector2(200, 360)
@export var enemy_spawn_pos: Vector2  = Vector2(900, 360)
@onready var bg: Sprite2D        = $"Background"
@onready var player: Player      = $"Player"
@onready var cam: Camera2D       = $"Player/Camera2D"
@onready var enemy_spawn: Marker2D = $"EnemySpawn"
@onready var z1: Enemy           = $"z1"
@onready var z2: Enemy           = $"z2"
@onready var boss: Enemy         = $"boss"

var current_enemy: Enemy = null
var run_timer: Timer
var phase := Phase.EXPLORE
var stage := 0
var guard_active := false

# Simple UI built in code so you don't need to make it
var ui: Control; var info_label: Label; var player_hp: Label; var enemy_hp: Label
var btn_attack: Button; var btn_guard: Button; var btn_heal: Button
var lbl_timer: Label; var lbl_stage: Label; var result_lbl: Label

func _ready() -> void:
	# Camera 4.4
	cam.enabled = true
	# Z order
	player.z_index = 1; z1.z_index = 1; z2.z_index = 1; boss.z_index = 1; bg.z_index = -10
	_build_ui()
	_build_timer()
	# Show initial sprites (since textures are assigned in Inspector)
	player._on_revert(); z1._on_revert(); z2._on_revert(); boss._on_revert()
	_setup_camera_limits()
	enemy_spawn.position = enemy_spawn_pos
	# place things
	player.position        = player_start
	enemy_spawn.position   = enemy_spawn_pos

# camera must truly center on player
	cam.enabled            = true
	cam.anchor_mode        = Camera2D.ANCHOR_MODE_DRAG_CENTER
	cam.position           = Vector2.ZERO     # local to Player
	cam.offset             = Vector2.ZERO     # no screen offset
	cam.zoom               = Vector2.ONE

	_start_run()

func _build_ui() -> void:
	var cl := CanvasLayer.new(); add_child(cl)
	ui = Control.new(); ui.visible = false; ui.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(ui)
	info_label = Label.new(); info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ui.add_child(info_label)
	player_hp  = Label.new(); ui.add_child(player_hp)
	enemy_hp   = Label.new(); ui.add_child(enemy_hp)
	lbl_timer  = Label.new(); ui.add_child(lbl_timer)
	lbl_stage  = Label.new(); ui.add_child(lbl_stage)
	player_hp.position = Vector2(10,10); enemy_hp.position = Vector2(10,34)
	lbl_stage.position = Vector2(10,58); lbl_timer.position = Vector2(1000,10)
	info_label.position = Vector2(0,10); info_label.size = Vector2(1152,24)
	var btns := HBoxContainer.new(); btns.anchor_left = 0.5; btns.anchor_right = 0.5; btns.position = Vector2(576, 600); ui.add_child(btns)
	btn_attack = Button.new(); btn_attack.text="Attack"; btns.add_child(btn_attack)
	btn_guard  = Button.new(); btn_guard.text ="Guard";  btns.add_child(btn_guard)
	btn_heal   = Button.new(); btn_heal.text  ="Heal";   btns.add_child(btn_heal)
	btn_attack.pressed.connect(_on_attack); btn_guard.pressed.connect(_on_guard); btn_heal.pressed.connect(_on_heal)
	result_lbl = Label.new(); result_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; result_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new(); ls.font_size = 96; result_lbl.label_settings = ls
	result_lbl.visible = false; cl.add_child(result_lbl)

func _build_timer() -> void:
	run_timer = Timer.new(); run_timer.one_shot = true; add_child(run_timer)
	run_timer.timeout.connect(_on_run_timer_timeout)

func _setup_camera_limits() -> void:
	if bg.texture == null: return
	var tex := bg.texture
	var world_w := int(tex.get_width()  * abs(bg.scale.x))
	var world_h := int(tex.get_height() * abs(bg.scale.y))
	var vs := get_viewport().get_visible_rect().size
	cam.limit_left = 0
	cam.limit_top  = 0
	cam.limit_right  = int(max(0, world_w - int(vs.x)))
	cam.limit_bottom = int(max(0, world_h - int(vs.y)))

func _start_run() -> void:
	run_timer.wait_time = 300.0
	run_timer.start()
	_start_stage(1)

func _start_stage(s: int) -> void:
	stage = s
	if s == 1:
		current_enemy = z1
		z1.max_hp = 40; z1.atk = 10; z1.defense = 2
	elif s == 2:
		current_enemy = z2
	else:
		current_enemy = boss
	# scale stats: z2 = 2x z1, boss = 4x z1
	z1.apply_multiplier(1.0)
	z2.max_hp=z1.max_hp; z2.atk=z1.atk; z2.defense=z1.defense; z2.apply_multiplier(2.0)
	boss.max_hp=z1.max_hp; boss.atk=z1.atk; boss.defense=z1.defense; boss.apply_multiplier(4.0)
	# place & show only the current enemy
	current_enemy.global_position = enemy_spawn.global_position
	current_enemy.sprite.flip_h = true
	z1.visible = current_enemy == z1; z2.visible = current_enemy == z2; boss.visible = current_enemy == boss
	lbl_stage.text = "Stage %d" % s
	_start_combat()

func _advance_or_win() -> void: 
	if stage < 3: _start_stage(stage + 1) 
	else: _win()
func _start_combat() -> void:
	player.set_free_roam(false); ui.visible = true; phase = Phase.PLAYER_TURN; guard_active = false
	_update_labels("A wild %s appears!" % current_enemy.display_name)
func _end_combat_ui() -> void: ui.visible = false; player.set_free_roam(true); phase = Phase.EXPLORE

func _update_labels(extra := "") -> void:
	player_hp.text = "Player HP: %d/%d" % [player.hp, player.max_hp]
	enemy_hp.text  = "%s HP: %d/%d" % [current_enemy.display_name, current_enemy.hp, current_enemy.max_hp]
	info_label.text = extra

func _process(_dt: float) -> void:
	if run_timer == null or run_timer.is_stopped(): return
	var t := int(ceil(run_timer.time_left)); var m := t / 60; var s := t % 60
	lbl_timer.text = "Timer: %02d:%02d" % [m, s]

func _on_attack() -> void:
	if phase != Phase.PLAYER_TURN: return
	player.swing(); current_enemy.take_damage(player.atk); _update_labels("You attack!")
	if current_enemy.is_dead():
		await get_tree().create_timer(0.35).timeout; _end_combat_ui(); _advance_or_win(); return
	await get_tree().create_timer(0.25).timeout; phase = Phase.ENEMY_TURN; _enemy_act()

func _on_guard() -> void:
	if phase != Phase.PLAYER_TURN: return
	player.guard(); guard_active = true; _update_labels("You guard (halve next hit).")
	await get_tree().create_timer(0.25).timeout; phase = Phase.ENEMY_TURN; _enemy_act()

func _on_heal() -> void:
	if phase != Phase.PLAYER_TURN: return
	player.heal_small(); _update_labels("You patch up.")
	await get_tree().create_timer(0.25).timeout; phase = Phase.ENEMY_TURN; _enemy_act()

func _enemy_act() -> void:
	if phase != Phase.ENEMY_TURN or current_enemy == null: return
	var do_attack := randf() < 0.8 or player.hp <= 15
	if do_attack:
		current_enemy.swing(); var dmg := current_enemy.atk
		if guard_active: dmg = int(ceil(dmg * 0.5))
		player.apply_damage(dmg); guard_active = false
		_update_labels("%s hits you!" % current_enemy.display_name)
	else:
		current_enemy.guard(); _update_labels("%s is guarding…" % current_enemy.display_name)
		current_enemy.defense += 999; await get_tree().create_timer(0.1).timeout; current_enemy.defense -= 999
	_update_labels()
	if player.hp <= 0: _lose("You died."); return
	phase = Phase.PLAYER_TURN

func _on_run_timer_timeout() -> void:
	if !(stage == 3 and current_enemy != null and current_enemy.is_dead()): _lose("Time up!")
func _win() -> void: run_timer.stop(); _show_result(true, "YOU WIN");  phase = Phase.WIN
func _lose(reason: String) -> void: run_timer.stop(); _show_result(false, "YOU LOSE\n" + reason); phase = Phase.LOSE
func _show_result(_w: bool, text: String) -> void:
	_end_combat_ui(); result_lbl.text = text; result_lbl.visible = true; get_tree().paused = true
