extends Node
## GramJeevan main screen (v0.2): field, animals, market, lesson and festival.

const GameState = preload("res://scripts/game_state.gd")
const Content = preload("res://scripts/content.gd")
const SAVE_PATH := "user://gramjeevan_save_v2.json"
const DARK := Color(0.20, 0.12, 0.05)
const PHASE_COLORS := [
	Color(0.99, 0.86, 0.55),
	Color(0.55, 0.80, 0.96),
	Color(0.96, 0.56, 0.32),
	Color(0.07, 0.09, 0.24),
]
const PLOT_NAMES := ["Empty", "Seeded", "Watered", "Ready!"]
const PLOT_COLORS := [
	Color(0.76, 0.58, 0.36),
	Color(0.62, 0.80, 0.38),
	Color(0.40, 0.68, 0.92),
	Color(0.99, 0.82, 0.22),
]

var state = GameState.new()
var bg: ColorRect
var stars: Array = []
var status_label: Label
var stats_label: Label
var msg_label: Label
var flavor_label: Label
var plot_buttons: Array = []
var animal_buttons: Array = []
var market_button: Button
var lesson_button: Button
var festival_button: Button
var next_button: Button
var lesson_overlay: CenterContainer
var lesson_q: Label
var lesson_buttons: Array = []
var lesson_result: Label
var lesson_close: Button


func _ready() -> void:
	_load_game()
	_build_ui()
	_refresh("Welcome to GramJeevan! Sow seeds, feed the animals and enjoy village life.")


# ---------------------------------------------------------------- UI helpers
func _box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(10)
	return sb


func _paint(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", _box(color))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.15)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, DARK)


func _make_button(text: String, color: Color, font_size: int, min_h: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", font_size)
	_paint(b, color)
	return b


func _make_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", DARK)
	return l


# ---------------------------------------------------------------- build
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	bg = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 24:
		var star := ColorRect.new()
		star.color = Color(1, 1, 0.8)
		star.size = Vector2(6, 6)
		star.position = Vector2((i * 97) % 700 + 10, (i * 211) % 1250 + 10)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(star)
		stars.append(star)

	var margin := MarginContainer.new()
	layer.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(1, 0.98, 0.92, 0.88)))
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(_make_label("GramJeevan", 52))
	status_label = _make_label("", 36)
	box.add_child(status_label)
	stats_label = _make_label("", 28)
	box.add_child(stats_label)
	msg_label = _make_label("", 28)
	box.add_child(msg_label)
	flavor_label = _make_label("", 24)
	box.add_child(flavor_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for i in GameState.PLOT_COUNT:
		var b := _make_button("", PLOT_COLORS[0], 30, 140)
		b.pressed.connect(_on_plot_pressed.bind(i))
		grid.add_child(b)
		plot_buttons.append(b)

	var animal_row := HBoxContainer.new()
	animal_row.add_theme_constant_override("separation", 12)
	box.add_child(animal_row)
	for i in GameState.ANIMALS.size():
		var a := _make_button("", PLOT_COLORS[0], 26, 110)
		a.pressed.connect(_on_animal_pressed.bind(i))
		animal_row.add_child(a)
		animal_buttons.append(a)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	box.add_child(action_row)
	market_button = _make_button("Market: Sell", Color(0.95, 0.75, 0.35), 28, 100)
	market_button.pressed.connect(_on_market_pressed)
	action_row.add_child(market_button)
	lesson_button = _make_button("Village Lesson", Color(0.70, 0.88, 0.60), 28, 100)
	lesson_button.pressed.connect(_open_lesson)
	action_row.add_child(lesson_button)
	festival_button = _make_button("Join Festival!", Color(0.98, 0.55, 0.75), 28, 100)
	festival_button.pressed.connect(_on_festival_pressed)
	action_row.add_child(festival_button)

	next_button = _make_button("Next", Color(0.60, 0.75, 0.98), 36, 110)
	next_button.pressed.connect(_on_next_pressed)
	box.add_child(next_button)

	_build_lesson_overlay(layer)


func _build_lesson_overlay(layer: CanvasLayer) -> void:
	lesson_overlay = CenterContainer.new()
	layer.add_child(lesson_overlay)
	lesson_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lesson_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	lesson_overlay.hide()
	var lp := PanelContainer.new()
	lp.custom_minimum_size = Vector2(620, 0)
	lp.add_theme_stylebox_override("panel", _box(Color(1, 0.97, 0.85)))
	lesson_overlay.add_child(lp)
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 14)
	lp.add_child(lbox)
	lbox.add_child(_make_label("Village Lesson", 38))
	lesson_q = _make_label("", 32)
	lbox.add_child(lesson_q)
	for i in 3:
		var ob := _make_button("", Color(0.70, 0.88, 0.60), 30, 90)
		ob.pressed.connect(_on_lesson_answer.bind(i))
		lbox.add_child(ob)
		lesson_buttons.append(ob)
	lesson_result = _make_label("", 28)
	lbox.add_child(lesson_result)
	lesson_close = _make_button("OK", Color(0.95, 0.75, 0.35), 32, 90)
	lesson_close.pressed.connect(_on_lesson_close)
	lbox.add_child(lesson_close)


# ---------------------------------------------------------------- actions
func _on_plot_pressed(i: int) -> void:
	_refresh(state.tap_plot(i))
	_save_game()


func _on_animal_pressed(i: int) -> void:
	_refresh(state.feed_animal(i))
	_save_game()


func _on_market_pressed() -> void:
	_refresh(state.sell_goods())
	_save_game()


func _on_festival_pressed() -> void:
	_refresh(state.join_festival())
	_save_game()


func _on_next_pressed() -> void:
	_refresh(state.next_phase())
	_save_game()


func _open_lesson() -> void:
	if state.lesson_done:
		_refresh("You finished today's lesson. Come back tomorrow.")
		return
	var idx: int = (state.day - 1) % Content.LESSONS.size()
	var lesson: Dictionary = Content.LESSONS[idx]
	lesson_q.text = str(lesson["q"])
	for i in 3:
		lesson_buttons[i].text = str(lesson["options"][i])
		lesson_buttons[i].show()
	lesson_result.text = ""
	lesson_close.hide()
	lesson_overlay.show()


func _on_lesson_answer(i: int) -> void:
	var idx: int = (state.day - 1) % Content.LESSONS.size()
	var lesson: Dictionary = Content.LESSONS[idx]
	var correct: bool = (i == int(lesson["answer"]))
	var reward: String = state.finish_lesson(correct)
	var verdict := "Correct! " if correct else "Not quite. "
	lesson_result.text = verdict + str(lesson["why"]) + "\n" + reward
	for b in lesson_buttons:
		b.hide()
	lesson_close.show()
	_refresh()
	_save_game()


func _on_lesson_close() -> void:
	lesson_overlay.hide()


# ---------------------------------------------------------------- display
func _refresh(msg: String = "") -> void:
	var p: int = state.phase
	bg.color = PHASE_COLORS[p]
	for s in stars:
		s.visible = (p == 3)
	var fest := ""
	if state.is_festival_day():
		fest = "   FESTIVAL DAY!"
	status_label.text = "Day %d  %s%s" % [state.day, GameState.PHASE_NAMES[p], fest]
	stats_label.text = "Coins %d   Grain %d   Milk %d   Eggs %d\nKnowledge %d   Joy %d" % [
		state.coins, state.grain, state.milk, state.eggs, state.knowledge, state.joy]
	if msg != "":
		msg_label.text = msg
	flavor_label.text = str(Content.FLAVOR[p])
	for i in plot_buttons.size():
		var s: int = state.plots[i]
		var b: Button = plot_buttons[i]
		b.text = PLOT_NAMES[s]
		_paint(b, PLOT_COLORS[s])
	for i in animal_buttons.size():
		var a: Button = animal_buttons[i]
		var is_fed: bool = state.fed[i]
		a.text = "%s\n%s" % [GameState.ANIMALS[i], "Fed" if is_fed else "Hungry"]
		_paint(a, Color(0.66, 0.85, 0.55) if is_fed else Color(0.90, 0.72, 0.55))
	festival_button.visible = state.is_festival_day() and p == 3 and not state.festival_joined
	next_button.text = "Next: %s" % GameState.PHASE_NAMES[(p + 1) % GameState.PHASE_NAMES.size()]


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
