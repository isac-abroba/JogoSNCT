extends Area2D

@export var speed = 120.0
@export var lifetime = 3.0        # segundos até sumir
@export var fade_time = 0.5       # tempo da piscada/fade no final
@export var spin_speed = 12.0     # rotação do osso (radianos/s)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var direction = 1
var life_timer = 0.0

func _ready() -> void:
	life_timer = lifetime

func set_direction(dir: int) -> void:
	direction = dir

func _physics_process(delta: float) -> void:
	position.x += speed * direction * delta
	anim.rotation += spin_speed * direction * delta
	
	life_timer -= delta
	
	# fade no final da vida
	if life_timer <= fade_time:
		anim.modulate.a = clamp(life_timer / fade_time, 0.0, 1.0)
	
	if life_timer <= 0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if body.has_method("take_damage"):
			body.take_damage()
		queue_free()
	elif body is TileMapLayer or body is TileMap:
		# bateu na parede/chão
		queue_free()
