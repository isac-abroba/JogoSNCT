extends Label

func _process(delta):
	$"../Pinguincortado".visible = Dados.vidas >= 1
	$"../Pinguincortado2".visible = Dados.vidas >= 2
	$"../Pinguincortado3".visible = Dados.vidas >= 3
