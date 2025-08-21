extends Node2D
class_name Enemy

@export var display_name := "Enemy"
@export var max_hp := 40
@export var atk := 10
@export var defense := 2

# 👉 drag textures in Inspector
@export var tex_idle: Texture2D
@export var tex_attack: Texture2D
@export var tex_hurt: Texture2D
@export var tex_guard: Texture2D

var hp: int
var base_hp0: int
var base_atk0: int
var base_def0: int

@onready var sprite: Sprite2D = Sprite2D.new()
@onready var revert_timer: Timer = Timer.new()

func _ready() -> void:
	add_child(sprite)
	add_child(revert_timer)
	revert_timer.one_shot = true
	revert_timer.wait_time = 0.25
	revert_timer.timeout.connect(_on_revert)
	base_hp0 = max_hp; base_atk0 = atk; base_def0 = defense
	hp = max_hp
	_on_revert() # show idle immediately

func apply_multiplier(m: float) -> void:
	max_hp = int(round(base_hp0 * m))
	atk = int(round(base_atk0 * m))
	defense = int(round(base_def0 * m))
	hp = max_hp

func take_damage(dmg: int) -> void:
	var real: int = max(1, dmg - defense)
	hp = max(hp - real, 0)
	if tex_hurt: sprite.texture = tex_hurt
	revert_timer.start()

func swing() -> void: if tex_attack: sprite.texture = tex_attack; revert_timer.start()
func guard() -> void: if tex_guard:  sprite.texture = tex_guard;  revert_timer.start()
func is_dead() -> bool: return hp <= 0
func _on_revert() -> void: if tex_idle: sprite.texture = tex_idle
