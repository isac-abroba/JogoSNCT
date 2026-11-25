extends Camera2D

# --- CONFIGURAÇÕES DA CÂMERA ---
@export_category("Seguidor")
@export var target_group: String = "Player"
@export var smooth_speed: float = 5.0        # Velocidade da suavização (maior = mais rápida)

@export_category("Olhar à Frente (Look Ahead)")
@export var look_ahead_distance: float = 120.0 # Distância que a câmera antecipa
@export var look_ahead_speed: float = 2.5     # Velocidade de transição da antecipação

# --- VARIÁVEIS INTERNAS ---
var target: Node2D = null
var target_facing: float = 1.0
var look_ahead_offset: float = 0.0

func _ready() -> void:
	find_target()

func _process(delta: float) -> void:
	# 1. Garante que o alvo é válido, senão tenta buscar novamente
	if not is_instance_valid(target):
		find_target()
		return
	
	# 2. Lógica do Look Ahead (Olhar à Frente) otimizada para o Sprite
	# Buscamos o AnimatedSprite2D dentro do player para saber a direção exata
	var player_sprite = target.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	
	if player_sprite:
		# Se flip_h for true, ele está olhando para a esquerda (-1), senão para a direita (1)
		target_facing = -1.0 if player_sprite.flip_h else 1.0
	
	# Suaviza a posição do foco à frente
	var target_look_ahead = target_facing * look_ahead_distance
	look_ahead_offset = lerp(look_ahead_offset, target_look_ahead, look_ahead_speed * delta)
	
	# 3. Posição Alvo Desejada (Posição do Player + Antecipação)
	var desired_position = target.global_position
	desired_position.x += look_ahead_offset
	
	# 4. Movimento Suavizado da Câmera (Lerp)
	global_position = global_position.lerp(desired_position, smooth_speed * delta)

# --- FUNÇÕES UTILITÁRIAS ---

# Busca o jogador na cena de forma dinâmica e adiciona no grupo se necessário
func find_target() -> void:
	var nodes = get_tree().get_nodes_in_group(target_group)
	if nodes.size() > 0:
		target = nodes[0]
