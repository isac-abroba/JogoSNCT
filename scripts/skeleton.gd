extends CharacterBody2D

enum SkeletonState {
	walk,
	chase,
	attack,
	dead
}

const SPINNING_BONE = preload("res://entities/spinning_bone.tscn")

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ground_detector: RayCast2D = $GroundDetector
@onready var player_detector: RayCast2D = $PlayerDetector
@onready var back_detector: RayCast2D = find_child("BackDetector") as RayCast2D
@onready var bone_start_position: Node2D = $BoneStartPosition

@export var sprite_faces_right = false
@export var patrol_speed = 20.0
@export var chase_speed = 45.0
@export var attack_range = 70.0
@export var lose_sight_time = 1.5
@export var attack_cooldown_time = 1.5

var status: SkeletonState
var direction = -1
var can_throw = true
var attack_cooldown = 0.0
var lost_timer = 0.0


func _ready() -> void:
	direction = -1
	if sprite_faces_right:
		scale.x = -1
	go_to_walk_state()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	match status:
		SkeletonState.walk:
			walk_state(delta)
		SkeletonState.chase:
			chase_state(delta)
		SkeletonState.attack:
			attack_state(delta)
		SkeletonState.dead:
			dead_state(delta)

	move_and_slide()

func go_to_walk_state():
	status = SkeletonState.walk
	anim.play("walk")

func go_to_chase_state():
	status = SkeletonState.chase
	lost_timer = lose_sight_time
	anim.play("walk")

func go_to_attack_state():
	status = SkeletonState.attack
	anim.play("attack")
	velocity.x = 0
	can_throw = true
	attack_cooldown = attack_cooldown_time

func go_to_dead_state():
	status = SkeletonState.dead
	anim.play("dead")
	hitbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	velocity = Vector2.ZERO

func walk_state(_delta):
	velocity.x = patrol_speed * direction
	
	if is_on_floor() and is_blocked():
		turn_around()
	
	if player_detector.is_colliding():
		go_to_chase_state()
		return
	
	if back_detector.is_colliding():
		turn_around()
		go_to_chase_state()

func chase_state(delta):
	if player_detector.is_colliding():
		lost_timer = lose_sight_time
		
		var distance = global_position.distance_to(player_detector.get_collision_point())
		if distance <= attack_range and attack_cooldown <= 0:
			go_to_attack_state()
			return
	elif back_detector.is_colliding():
		turn_around()
		lost_timer = lose_sight_time
	else:
		lost_timer -= delta
		if lost_timer <= 0:
			go_to_walk_state()
			return
	
	if is_on_floor() and is_blocked():
		velocity.x = 0
	else:
		velocity.x = chase_speed * direction

func attack_state(_delta):
	velocity.x = 0
	if anim.frame >= 2 and can_throw:
		throw_bone()
		can_throw = false

func dead_state(_delta):
	velocity.x = 0

func is_blocked() -> bool:
	return wall_detector.is_colliding() or not ground_detector.is_colliding()

func turn_around():
	scale.x *= -1
	direction *= -1

func take_damage() -> bool:
	if status == SkeletonState.dead:
		return false
	
	go_to_dead_state()
	return true

func throw_bone():
	var new_bone = SPINNING_BONE.instantiate()
	add_sibling(new_bone)
	new_bone.global_position = bone_start_position.global_position
	new_bone.set_direction(direction)

func _on_animated_sprite_2d_animation_finished() -> void:
	if anim.animation == "attack" and status == SkeletonState.attack:
		go_to_chase_state()
