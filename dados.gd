
extends Node

var vidas: int = 3

func perder_vida() -> void:
	if vidas > 0:
		vidas -= 1
		print("Vidas restantes: ", vidas)


func recuperar_vida() -> void:
	if vidas < 3:
		vidas += 1


func reiniciar_vidas() -> void:
	vidas = 3
	print("Vidas restauradas!")
