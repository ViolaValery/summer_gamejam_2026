extends Label
## Kurzes schwebendes "-500" (rot) / "+500" (grün) am Budget, das nach oben
## steigt und ausblendet. Schrift/Größe stecken in der Szene; hier nur die
## Animation und Vorzeichen/Farbe-Logik.

func show_delta(amount: int) -> void:
	if amount < 0:
		text = str(amount)                       # "-500"
		modulate = Color(1.0, 0.27, 0.22)        # rot = ausgegeben
	else:
		text = "+" + str(amount)                 # "+500"
		modulate = Color(0.3, 1.0, 0.45)         # grün = zurück
	pivot_offset = size / 2.0

	var tw := create_tween()
	tw.set_parallel(true)
	# leicht aufpoppen, hochschweben, ausblenden
	tw.tween_property(self, "position:y", position.y - 58, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
