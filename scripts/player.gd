
extends CharacterBody2D

enum PlayerState {
	idle,
	walk,
	jump,
	fall,
	duck,
	dead
}

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var reload_timer: Timer = $ReloadTimer
@onready var hitbox_shape: CollisionShape2D = $HitBox.find_child("CollisionShape2D", true, false) as CollisionShape2D
@onready var jump_sound: AudioStreamPlayer = $jump_sound as AudioStreamPlayer

# CONFIGURAÇÕES
const SPEED: float = 75.0
const JUMP_VELOCITY: float = -300.0
const DUCK_COLLISION_HEIGHT: float = 12.0
const DUCK_RADIUS_RATIO: float = 0.6
const DUCK_HITBOX_RATIO: float = 0.6
const BOUNCE_VELOCITY: float = -220.0

# SISTEMA DE INVENCIBILIDADE
const TEMPO_INVENCIBILIDADE: float = 1.5
const TEMPO_PISCAR: float = 0.05

var invencivel: bool = false

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var status: PlayerState = PlayerState.idle

var original_collision_size: Vector2
var original_collision_position: Vector2
var original_capsule_height: float
var original_capsule_position: Vector2
var original_circle_radius: float
var original_circle_position: Vector2
var original_collision_shape: Shape2D

var original_hitbox_shape: Shape2D
var original_hitbox_position: Vector2

# INIMIGOS JÁ ATINGIDOS
var enemies_hit: Array[Node] = []


func _ready() -> void:

	if animated_sprite_2d == null or collision_shape_2d == null:
		push_error("Faltando nós do Player!")
		return

	if animated_sprite_2d.sprite_frames == null:
		push_error("AnimatedSprite2D sem SpriteFrames!")
		return

	if collision_shape_2d.shape == null:
		push_error("CollisionShape2D sem forma!")
		return

	collision_shape_2d.shape = collision_shape_2d.shape.duplicate()
	original_collision_shape = collision_shape_2d.shape

	if original_collision_shape is RectangleShape2D:
		original_collision_size = original_collision_shape.size
		original_collision_position = collision_shape_2d.position

	elif original_collision_shape is CapsuleShape2D:
		original_capsule_height = original_collision_shape.height
		original_capsule_position = collision_shape_2d.position

	elif original_collision_shape is CircleShape2D:
		original_circle_radius = original_collision_shape.radius
		original_circle_position = collision_shape_2d.position

	if hitbox_shape != null and hitbox_shape.shape != null:
		hitbox_shape.shape = hitbox_shape.shape.duplicate()
		original_hitbox_shape = hitbox_shape.shape.duplicate()
		original_hitbox_position = hitbox_shape.position
	else:
		push_warning("CollisionShape2D da HitBox não encontrado!")

	go_to_idle_state()


# FÍSICA E ESTADOS
func _physics_process(delta: float) -> void:

	if status == PlayerState.dead:
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	match status:
		PlayerState.idle:
			idle_state()

		PlayerState.walk:
			walk_state()

		PlayerState.jump:
			jump_state()

		PlayerState.fall:
			fall_state()

		PlayerState.duck:
			duck_state()

		PlayerState.dead:
			dead_state()

	move_and_slide()

	if not is_on_floor() and status == PlayerState.jump and velocity.y >= 0:
		go_to_fall_state()


# ==================================
# SISTEMA DE VIDAS E DANO
# ==================================

func receber_dano() -> void:

	if invencivel or status == PlayerState.dead:
		return

	# Ativa invencibilidade
	invencivel = true

	# Perde uma vida
	Dados.perder_vida()

	print("Vidas restantes: ", Dados.vidas)

	# Verifica se perdeu todas as vidas
	if Dados.vidas <= 0:
		animated_sprite_2d.visible = true
		go_to_dead_state()
		return

	# PISCAR ESTILO SUPER MARIO
	var tempo_total: float = 0.0

	while tempo_total < TEMPO_INVENCIBILIDADE:

		animated_sprite_2d.visible = false
		await get_tree().create_timer(TEMPO_PISCAR).timeout

		if not is_inside_tree() or status == PlayerState.dead:
			return

		animated_sprite_2d.visible = true
		await get_tree().create_timer(TEMPO_PISCAR).timeout

		if not is_inside_tree() or status == PlayerState.dead:
			return

		tempo_total += TEMPO_PISCAR * 2.0

	# Garante que fique visível
	animated_sprite_2d.visible = true

	# Finaliza invencibilidade
	invencivel = false


# ==================================
# SISTEMA DE MORTE
# ==================================

func go_to_dead_state() -> void:

	if status == PlayerState.dead:
		return

	status = PlayerState.dead
	velocity = Vector2.ZERO
	animated_sprite_2d.visible = true

	if animated_sprite_2d.sprite_frames.has_animation("dead"):
		animated_sprite_2d.play("dead")

	if reload_timer:
		reload_timer.start()


func dead_state() -> void:
	velocity.x = 0


# ==================================
# AGACHAMENTO
# ==================================

func is_duck_pressed() -> bool:

	if InputMap.has_action("duck") and Input.is_action_pressed("duck"):
		return true

	return Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S)


func can_stand_up() -> bool:

	var space_state = get_world_2d().direct_space_state

	var height_to_check: float = original_collision_size.y

	if original_collision_shape is CapsuleShape2D:
		height_to_check = original_capsule_height

	if original_collision_shape is CircleShape2D:
		height_to_check = original_circle_radius * 2.0

	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, -height_to_check),
		1
	)

	query.exclude = [get_rid()]

	return space_state.intersect_ray(query).is_empty()


# ==================================
# DIREÇÃO
# ==================================

func update_direction() -> void:

	var direction = Input.get_axis("left", "right")

	if direction < 0:
		animated_sprite_2d.flip_h = true

	elif direction > 0:
		animated_sprite_2d.flip_h = false


# ==================================
# COLISÃO DO AGACHAMENTO
# ==================================

func set_duck_collision() -> void:

	if collision_shape_2d.shape is RectangleShape2D:
		var rect = collision_shape_2d.shape as RectangleShape2D

		rect.size.y = min(DUCK_COLLISION_HEIGHT, original_collision_size.y)

		collision_shape_2d.position.y = original_collision_position.y + (
			(original_collision_size.y - rect.size.y) / 2.0
		)

	elif collision_shape_2d.shape is CapsuleShape2D:
		var capsule = collision_shape_2d.shape as CapsuleShape2D

		capsule.height = max(
			min(DUCK_COLLISION_HEIGHT, original_capsule_height),
			capsule.radius * 2.0
		)

		collision_shape_2d.position.y = original_capsule_position.y + (
			(original_capsule_height - capsule.height) / 2.0
		)

	elif collision_shape_2d.shape is CircleShape2D:
		var circle = collision_shape_2d.shape as CircleShape2D

		circle.radius = original_circle_radius * DUCK_RADIUS_RATIO

		collision_shape_2d.position.y = original_circle_position.y + (
			original_circle_radius - circle.radius
		)

	set_duck_hitbox()


func restore_collision() -> void:

	if original_collision_shape == null:
		return

	if original_collision_shape is RectangleShape2D:
		var rect = collision_shape_2d.shape as RectangleShape2D
		rect.size = original_collision_size
		collision_shape_2d.position = original_collision_position

	elif original_collision_shape is CapsuleShape2D:
		var capsule = collision_shape_2d.shape as CapsuleShape2D
		capsule.height = original_capsule_height
		collision_shape_2d.position = original_capsule_position

	elif original_collision_shape is CircleShape2D:
		var circle = collision_shape_2d.shape as CircleShape2D
		circle.radius = original_circle_radius
		collision_shape_2d.position = original_circle_position

	restore_hitbox()


# ==================================
# HITBOX DO AGACHAMENTO
# ==================================

func set_duck_hitbox() -> void:

	if hitbox_shape == null or original_hitbox_shape == null:
		return

	if hitbox_shape.shape is CircleShape2D:
		var circle = hitbox_shape.shape as CircleShape2D
		var orig = original_hitbox_shape as CircleShape2D

		circle.radius = orig.radius * DUCK_HITBOX_RATIO

		hitbox_shape.position.y = original_hitbox_position.y + (
			orig.radius - circle.radius
		)

	elif hitbox_shape.shape is RectangleShape2D:
		var rect = hitbox_shape.shape as RectangleShape2D
		var orig = original_hitbox_shape as RectangleShape2D

		rect.size.y = orig.size.y * DUCK_HITBOX_RATIO

		hitbox_shape.position.y = original_hitbox_position.y + (
			(orig.size.y - rect.size.y) / 2.0
		)

	elif hitbox_shape.shape is CapsuleShape2D:
		var capsule = hitbox_shape.shape as CapsuleShape2D
		var orig = original_hitbox_shape as CapsuleShape2D

		capsule.height = max(orig.height * DUCK_HITBOX_RATIO, capsule.radius * 2.0)

		hitbox_shape.position.y = original_hitbox_position.y + (
			(orig.height - capsule.height) / 2.0
		)


func restore_hitbox() -> void:

	if hitbox_shape == null or original_hitbox_shape == null:
		return

	if hitbox_shape.shape is CircleShape2D:
		(hitbox_shape.shape as CircleShape2D).radius = (original_hitbox_shape as CircleShape2D).radius

	elif hitbox_shape.shape is RectangleShape2D:
		(hitbox_shape.shape as RectangleShape2D).size = (original_hitbox_shape as RectangleShape2D).size

	elif hitbox_shape.shape is CapsuleShape2D:
		(hitbox_shape.shape as CapsuleShape2D).height = (original_hitbox_shape as CapsuleShape2D).height

	hitbox_shape.position = original_hitbox_position


# ==================================
# ESTADOS DO PERSONAGEM
# ==================================

func go_to_idle_state() -> void:

	status = PlayerState.idle
	velocity.x = 0
	restore_collision()

	if animated_sprite_2d.sprite_frames.has_animation("idle"):
		animated_sprite_2d.play("idle")


func go_to_walk_state() -> void:

	status = PlayerState.walk
	restore_collision()

	if animated_sprite_2d.sprite_frames.has_animation("walk"):
		animated_sprite_2d.play("walk")


func go_to_jump_state() -> void:

	status = PlayerState.jump
	restore_collision()

	if animated_sprite_2d.sprite_frames.has_animation("jump"):
		animated_sprite_2d.play("jump")


func go_to_fall_state() -> void:

	status = PlayerState.fall
	restore_collision()

	if animated_sprite_2d.sprite_frames.has_animation("fall"):
		animated_sprite_2d.play("fall")


func go_to_duck_state() -> void:

	status = PlayerState.duck
	velocity.x = 0
	set_duck_collision()

	if animated_sprite_2d.sprite_frames.has_animation("duck"):
		animated_sprite_2d.play("duck")


# ==================================
# IDLE
# ==================================

func idle_state() -> void:

	if not is_on_floor():
		go_to_jump_state()
		return

	if is_duck_pressed():
		go_to_duck_state()
		return

	if Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		go_to_jump_state()
		jump_sound.play()
		return

	var direction = Input.get_axis("left", "right")
	update_direction()

	if direction != 0:
		go_to_walk_state()


# ==================================
# WALK
# ==================================

func walk_state() -> void:

	if not is_on_floor():
		go_to_jump_state()
		return

	if is_duck_pressed():
		go_to_duck_state()
		return

	if Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		go_to_jump_state()
		jump_sound.play()
		return

	var direction = Input.get_axis("left", "right")
	update_direction()

	if direction != 0:
		velocity.x = direction * SPEED
	else:
		go_to_idle_state()


# ==================================
# JUMP
# ==================================

func jump_state() -> void:

	var direction = Input.get_axis("left", "right")
	update_direction()

	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if velocity.y >= 0:
		go_to_fall_state()
		return

	if is_on_floor():
		if is_duck_pressed():
			go_to_duck_state()
		elif direction != 0:
			go_to_walk_state()
		else:
			go_to_idle_state()


# ==================================
# FALL
# ==================================

func fall_state() -> void:

	var direction = Input.get_axis("left", "right")
	update_direction()

	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if is_on_floor():
		if is_duck_pressed():
			go_to_duck_state()
		elif direction != 0:
			go_to_walk_state()
		else:
			go_to_idle_state()


# ==================================
# DUCK
# ==================================

func duck_state() -> void:

	velocity.x = 0

	if not is_on_floor():
		go_to_jump_state()
		return

	if animated_sprite_2d.animation != "duck":
		animated_sprite_2d.play("duck")

	update_direction()

	if is_duck_pressed():
		return

	if can_stand_up():
		var direction = Input.get_axis("left", "right")

		if direction != 0:
			go_to_walk_state()
		else:
			go_to_idle_state()


# ==================================
# COLISÃO COM INIMIGOS
# ==================================

func _on_hit_box_area_entered(area: Area2D) -> void:

	if status == PlayerState.dead:
		return

	# PROJÉTIL
	if area.is_in_group("projectile"):
		receber_dano()
		return

	var target = area.get_parent()

	if not is_instance_valid(target):
		return

	# VERIFICA SE ESTÁ CAINDO SOBRE O INIMIGO
	var stomp = (
		velocity.y > 0
		and global_position.y < target.global_position.y
	)

	if stomp:

		if target in enemies_hit:
			return

		if target.has_method("take_damage"):

			enemies_hit.append(target)

			var killed = target.take_damage()

			if killed:
				velocity.y = BOUNCE_VELOCITY
				go_to_jump_state()

			return

		elif target.has_method("die"):
			target.die()

		else:
			target.queue_free()

		velocity.y = BOUNCE_VELOCITY
		go_to_jump_state()

	else:
		# COLISÃO LATERAL
		receber_dano()


# ==================================
# REINICIAR FASE
# ==================================

func _on_reload_timer_timeout() -> void:

	# Restaura as três vidas
	Dados.reiniciar_vidas()

	# Reinicia a cena atual
	get_tree().reload_current_scene()
