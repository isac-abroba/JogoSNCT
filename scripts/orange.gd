extends CharacterBody2D

enum OrangeState { walk, chase, attack, dead }

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = get_node_or_null("Hitbox")

var player_detector: RayCast2D
var back_detector: RayCast2D
var ground_detector: RayCast2D
var wall_detector: RayCast2D

@export var sprite_faces_right = false
@export var patrol_speed = 20.0
@export var chase_speed = 60.0
@export var detect_range = 180.0     # reserva: distância até o player
@export var lose_range = 300.0
@export var attack_range = 50.0
@export var vertical_range = 60.0
@export var lose_sight_time = 1.5
@export var attack_hit_frame = 2
@export var attack_cooldown_time = 1.5
@export var attack_max_time = 1.5
@export var debug_key_kill = true    # tecla K mata o inimigo (teste)

# Tamanhos dos raycasts criados pelo código
@export var sight_distance = 150.0
@export var back_distance = 100.0
@export var wall_distance = 14.0
@export var ground_ahead = 14.0
@export var ground_depth = 40.0

var status: OrangeState = OrangeState.walk
var direction = -1
var attack_cooldown = 0.0
var attack_time = 0.0
var lost_timer = 0.0
var damage_done = false
var player: Node2D = null

var walk_anim = ""
var run_anim = ""
var attack_anim = ""
var dead_anim = ""


func _ready() -> void:
	direction = -1

	if sprite_faces_right:
		scale.x = -1

	setup_raycasts()

	anim.speed_scale = 1.0

	var names = anim.sprite_frames.get_animation_names()

	walk_anim = find_anim(["walk", "andar", "anda", "run", "corr"], names)
	run_anim = find_anim(["run", "corr", "walk", "andar", "anda"], names)
	attack_anim = find_anim(["attack", "atac", "atk", "hit"], names)
	dead_anim = find_anim(["dead", "death", "morr", "die"], names)

	anim.sprite_frames.set_animation_loop(attack_anim, false)
	anim.sprite_frames.set_animation_loop(dead_anim, false)

	go_to_walk_state()


# Usa o nó da cena se existir; senão cria um novo
func get_or_create_ray(node_name: String, pos: Vector2, target: Vector2, mask: int) -> RayCast2D:
	var ray = get_node_or_null(node_name) as RayCast2D

	if ray == null:
		ray = RayCast2D.new()
		ray.name = node_name
		ray.position = pos
		ray.target_position = target
		ray.collision_mask = mask
		add_child(ray)

	ray.enabled = true
	return ray


func setup_raycasts() -> void:
	# Direção "para frente" no espaço local do nó
	var fwd = 1.0 if sprite_faces_right else -1.0

	player_detector = get_or_create_ray("PlayerDetector", Vector2.ZERO, Vector2(fwd * sight_distance, 0), 0xFFFFFFFF)
	back_detector = get_or_create_ray("BackDetector", Vector2.ZERO, Vector2(-fwd * back_distance, 0), 0xFFFFFFFF)
	wall_detector = get_or_create_ray("WallDetector", Vector2.ZERO, Vector2(fwd * wall_distance, 0), 1)
	ground_detector = get_or_create_ray("GroundDetector", Vector2(fwd * ground_ahead, 0), Vector2(0, ground_depth), 1)


func _physics_process(delta: float) -> void:

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player") as Node2D

	if debug_key_kill and Input.is_key_pressed(KEY_K) and status != OrangeState.dead:
		take_damage()

	if not is_on_floor():
		velocity += get_gravity() * delta

	if attack_cooldown > 0:
		attack_cooldown -= delta

	match status:
		OrangeState.walk:
			walk_state()
		OrangeState.chase:
			chase_state(delta)
		OrangeState.attack:
			attack_state(delta)
		OrangeState.dead:
			velocity.x = 0

	move_and_slide()


# ---------- ANIMAÇÃO ----------

func find_anim(keywords: Array, names: PackedStringArray) -> String:
	for key in keywords:
		for n in names:
			if n.to_lower().contains(key):
				return n

	return names[0]


func play_anim(anim_name: String) -> void:
	if anim.animation != anim_name or not anim.is_playing():
		anim.play(anim_name)


# ---------- ESTADOS ----------

func go_to_walk_state() -> void:
	status = OrangeState.walk
	play_anim(walk_anim)


func go_to_chase_state() -> void:
	status = OrangeState.chase
	lost_timer = lose_sight_time
	play_anim(run_anim)


func go_to_attack_state() -> void:
	status = OrangeState.attack
	velocity.x = 0
	attack_cooldown = attack_cooldown_time
	attack_time = 0.0
	damage_done = false
	anim.play(attack_anim)


func go_to_dead_state() -> void:
	status = OrangeState.dead
	anim.play(dead_anim)

	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)

	# O player atravessa o corpo, mas ele fica apoiado no chão
	set_deferred("collision_layer", 0)

	velocity = Vector2.ZERO


func walk_state() -> void:
	play_anim(walk_anim)
	velocity.x = patrol_speed * direction

	if is_on_floor() and is_blocked():
		turn_around()

	if sees_player():
		face_player()
		go_to_chase_state()


func chase_state(delta: float) -> void:
	play_anim(run_anim)

	if player == null:
		go_to_walk_state()
		return

	if sees_player():
		lost_timer = lose_sight_time
	else:
		lost_timer -= delta

		if lost_timer <= 0:
			go_to_walk_state()
			return

	face_player()

	if player_in_range(attack_range):
		velocity.x = 0

		if attack_cooldown <= 0:
			go_to_attack_state()

		return

	if is_on_floor() and is_blocked():
		velocity.x = 0
	else:
		velocity.x = chase_speed * direction


func attack_state(delta: float) -> void:
	velocity.x = 0
	attack_time += delta

	if not damage_done and anim.frame >= attack_hit_frame:
		damage_done = true

		if player_in_range(attack_range + 10.0) and player.has_method("take_damage"):
			player.take_damage()

	if attack_time >= attack_max_time:
		go_to_chase_state()


# ---------- AUXILIARES ----------

func ray_sees_player(ray: RayCast2D) -> bool:
	if not ray.is_colliding():
		return false

	var collider = ray.get_collider()

	if collider != null and collider.is_in_group("Player"):
		player = collider as Node2D
		return true

	return false


func sees_player() -> bool:
	if ray_sees_player(player_detector) or ray_sees_player(back_detector):
		return true

	if player != null and is_instance_valid(player):
		var limit = detect_range
		if status == OrangeState.chase:
			limit = lose_range
		return player_in_range(limit)

	return false


func player_in_range(range_x: float) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	var dx = abs(player.global_position.x - global_position.x)
	var dy = abs(player.global_position.y - global_position.y)

	return dx <= range_x and dy <= vertical_range


func face_player() -> void:
	if player == null or not is_instance_valid(player):
		return

	var dir_to_player = sign(player.global_position.x - global_position.x)

	if dir_to_player != 0 and dir_to_player != direction:
		turn_around()


func is_blocked() -> bool:
	return wall_detector.is_colliding() or not ground_detector.is_colliding()


func turn_around() -> void:
	scale.x *= -1
	direction *= -1


func take_damage() -> bool:
	if status == OrangeState.dead:
		return false

	go_to_dead_state()
	return true


func _on_animated_sprite_2d_animation_finished() -> void:
	if status == OrangeState.attack and anim.animation == attack_anim:
		go_to_chase_state()
