extends Node
## GramJeevan main screen: a 3x3 field. Tap a plot to plant, water, harvest.

const GameState = preload("res://scripts/game_state.gd")
const SAVE_PATH := "user://gramjeevan_save.json"
const STATE_NAMES := ["Empty", "Seeded", "Watered", "Ready"]
const STATE_COLORS := [
	Color(0.55, 0.40, 0.25),
	Color(0.65, 0.75, 0.35),
	Color(0.35, 0.60, 0.90),
	Color(0.95, 0.80, 0.20),
]

var state = GameState.new()
var plot_buttons: Array = []
var hud_label: Label
var msg_label: Label


func _ready() -> void:
	_load_game()
	_build_ui()
	_refresh("Welcome to GramJeevan!")


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	layer.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 32)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	margin.add_child(box)

	var title := Label.new()
	title.text = "GramJeevan"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)

	hud_label = Label.new()
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_label.add_theme_font_size_override("font_size", 40)
	box.add_child(hud_label)

	msg_label = Label.new()
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 30)
	box.add_child(msg_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	box.add_child(grid)
	for i in GameState.PLOT_COUNT:
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 200)
		b.add_theme_font_size_override("font_size", 32)
		b.pressed.connect(_on_plot_pressed.bind(i))
		grid.add_child(b)
		plot_buttons.append(b)

	var day_button := Button.new()
	day_button.text = "Next Day"
	day_button.custom_minimum_size = Vector2(0, 120)
	day_button.add_theme_font_size_override("font_size", 40)
	day_button.pressed.connect(_on_next_day_pressed)
	box.add_child(day_button)


func _on_plot_pressed(i: int) -> void:
	var msg: String = state.tap_plot(i)
	_refresh(msg)
	_save_game()


func _on_next_day_pressed() -> void:
	state.next_day()
	_refresh("A new day begins.")
	_save_game()


func _refresh(msg: String = "") -> void:
	hud_label.text = "Day %d    Coins %d" % [state.day, state.coins]
	if msg != "":
		msg_label.text = msg
	for i in plot_buttons.size():
		var s: int = state.plots[i]
		var b: Button = plot_buttons[i]
		b.text = STATE_NAMES[s]
		b.modulate = STATE_COLORS[s]


func _save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state.to_dict()))


func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		state.from_dict(data)
