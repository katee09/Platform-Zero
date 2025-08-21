extends CharacterBody2D
class_name Player
@export var speed: float = 220.0
@export var max_hp: int = 60
@export var atk: int = 14
@export var defense: int = 3

# 👉 drag your textures in the Inspector
@export var tex_idle: Texture2D
@export var tex_walk: Texture2D
@export var tex_attack: Texture2D
@export var tex_hurt: Texture2D
@export var tex_guard: Texture2D

var hp: int
var can_move := true
@onready var sprite: Sprite2D = Sprite2D.new()
@onready var revert_timer: Timer = Timer.new()



func _ready() -> void:
	add_child(sprite)
	# draw the texture centered on the node position
	sprite.centered = true
	sprite.offset   = Vector2.ZERO
	# ... rest of your _ready()
	add_child(sprite)
	# draw the texture centered on the node position
	sprite.centered = true
	sprite.offset   = Vector2.ZERO
	# ... rest of your _ready()
	add_child(sprite)
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(28, 56)     # width, height in pixels (Godot 4 uses 'size')
		cs.shape = rect
		cs.position = Vector2(0, -4)    # nudge so feet line up nicely
		add_child(cs)

	add_child(revert_timer)
	revert_timer.one_shot = true
	revert_timer.wait_time = 0.25
	revert_timer.timeout.connect(_on_revert)
	hp = max_hp
	_on_revert() # show something immediately

func _physics_process(_dt: float) -> void:
	if !can_move:
		velocity = Vector2.ZERO
		move_and_slide(); return
	var dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = dir * speed
	move_and_slide()
	if dir != 0:
		sprite.flip_h = dir < 0
		sprite.texture = tex_walk if tex_walk else tex_idle
	else:
		_on_revert()

func set_free_roam(on: bool) -> void: can_move = on
func swing() -> void: if tex_attack: sprite.texture = tex_attack; revert_timer.start()
func guard() -> void: if tex_guard:  sprite.texture = tex_guard;  revert_timer.start()
func hurt()  -> void: if tex_hurt:   sprite.texture = tex_hurt;   revert_timer.start()
func apply_damage(dmg: int) -> void:
	var real: int = max(1, dmg - defense)
	hp = max(hp - real, 0)
	hurt()
func heal_small() -> void: hp = int(min(hp + 12, max_hp))
func _on_revert() -> void: if tex_idle: sprite.texture = tex_idle
