extends CharacterBody2D
class_name Player

@export var max_hp: int = 60
@export var atk: int = 20
@export var defense: int = 5

@export var tex_idle: Texture2D
@export var tex_walk: Texture2D
@export var tex_attack: Texture2D
@export var tex_hurt: Texture2D
@export var tex_guard: Texture2D

var hp: int
var can_move := false

@onready var sprite: Sprite2D = _find_sprite()
@onready var revert_timer: Timer = Timer.new()

func _ready() -> void:
	if sprite.get_parent() == null:
		add_child(sprite)
	sprite.centered = true
	sprite.offset = Vector2.ZERO

	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(28, 56)
		cs.shape = rect
		add_child(cs)

	add_child(revert_timer)
	revert_timer.one_shot = true
	revert_timer.wait_time = 0.5
	revert_timer.timeout.connect(_on_revert)

	hp = max_hp
	_on_revert()

func _physics_process(_dt: float) -> void:
	if not revert_timer.is_stopped():
		return
	if tex_idle:
		sprite.texture = tex_idle

func swing() -> void:
	if tex_attack: sprite.texture = tex_attack
	revert_timer.start()

func guard() -> void:
	if tex_guard: sprite.texture = tex_guard
	revert_timer.start()

func hurt() -> void:
	if tex_hurt: sprite.texture = tex_hurt
	revert_timer.start()

func apply_damage(dmg: int) -> void:
	var real: int = max(1, dmg - defense)
	hp = max(hp - real, 0)
	hurt()

func heal_small() -> void:
	hp = int(min(hp + 12, max_hp))

func _on_revert() -> void:
	if tex_idle:
		sprite.texture = tex_idle

func set_free_roam(on: bool) -> void:
	can_move = on

func set_stats(new_max_hp: int, new_atk: int, new_def: int, refill: bool = true, keep_ratio: bool = false) -> void:
	var old_max := max_hp
	max_hp = new_max_hp
	atk = new_atk
	defense = new_def

	if refill:
		hp = max_hp
	elif keep_ratio and old_max > 0:
		var pct := float(hp) / float(old_max)
		hp = clamp(int(round(pct * float(max_hp))), 0, max_hp)
	else:
		hp = clamp(hp, 0, max_hp)

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
