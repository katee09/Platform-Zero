extends Node2D
class_name Enemy

@export var display_name := "Enemy"
@export var max_hp := 40
@export var atk := 10
@export var defense := 2

@export var tex_idle: Texture2D
@export var tex_attack: Texture2D
@export var tex_hurt: Texture2D
@export var tex_guard: Texture2D

var hp: int

@onready var sprite: Sprite2D = _find_sprite()
@onready var revert_timer: Timer = Timer.new()

func _ready() -> void:
	if sprite.get_parent() == null:
		add_child(sprite)
	add_child(revert_timer)
	revert_timer.one_shot = true
	revert_timer.wait_time = 0.5
	revert_timer.timeout.connect(_on_revert)

	hp = max_hp
	_on_revert()

func take_damage(dmg: int) -> void:
	var real: int = max(1, dmg - defense)
	hp = max(hp - real, 0)
	if tex_hurt: sprite.texture = tex_hurt
	revert_timer.start()

func swing() -> void:
	if tex_attack: sprite.texture = tex_attack
	revert_timer.start()

func guard() -> void:
	if tex_guard: sprite.texture = tex_guard
	revert_timer.start()

func is_dead() -> bool:
	return hp <= 0

func _on_revert() -> void:
	if tex_idle:
		sprite.texture = tex_idle

func set_stats(new_max_hp: int, new_atk: int, new_def: int) -> void:
	max_hp = new_max_hp
	atk = new_atk
	defense = new_def
	hp = max_hp

func _find_sprite() -> Sprite2D:
	var chosen: Sprite2D = null
	for c in get_children():
		if c is Sprite2D:
			if chosen == null:
				chosen = c
			else:
				c.visible = false
	if chosen == null:
		chosen = Sprite2D.new()
		add_child(chosen)
	return chosen
