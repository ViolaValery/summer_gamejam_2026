extends PanelContainer
## Kurze Belohnungs-Anzeige (oben rechts) beim Erreichen eines Checkpoints:
## zeigt das gewonnene Budget (+X $) und neu freigeschaltete Items.
## Blendet ein, hält kurz, blendet aus und entfernt sich selbst.

func show_reward(level: int, budget_delta: int, item_names: Array) -> void:
	var list: VBoxContainer = $Margin/List

	var head := Label.new()
	head.text = "Checkpoint %d!" % level
	head.add_theme_font_size_override("font_size", 26)
	list.add_child(head)

	if budget_delta > 0:
		var g := Label.new()
		g.text = "+%d $" % budget_delta
		g.add_theme_font_size_override("font_size", 30)
		g.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		list.add_child(g)

	for n in item_names:
		var il := Label.new()
		il.text = "New: %s" % n
		il.add_theme_color_override("font_color", Color(0.45, 1, 0.5))
		list.add_child(il)

	# Einblenden -> halten -> ausblenden -> entfernen.
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
