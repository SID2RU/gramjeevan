extends SceneTree
## Headless test runner. Run with:
## godot --headless --path game --script res://tests/run_tests.gd

var failures: Array = []


func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		failures.append(label)


func _initialize() -> void:
	_test_scripts_parse()
	_test_game_state()
	_test_content()
	await _test_main_scene()
	if failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("TESTS FAILED: ", failures.size())
		quit(1)


func _test_scripts_parse() -> void:
	var dir := DirAccess.open("res://scripts")
	check(dir != null, "scripts folder opens")
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".gd"):
			var s = load("res://scripts/" + name)
			check(s != null and s.can_instantiate(), "script parses: " + name)
		name = dir.get_next()
	dir.list_dir_end()


func _test_game_state() -> void:
	var GS = load("res://scripts/game_state.gd")
	var g = GS.new()
	check(g.coins == 6 and g.day == 1 and g.phase == 0, "initial state")
	g.tap_plot(0)
	check(g.coins == 4 and g.plots[0] == GS.SEEDED, "planting costs 2 coins")
	g.tap_plot(0)
	check(g.plots[0] == GS.WATERED, "plot watered")
	for i in 4:
		g.next_phase()
	check(g.day == 2 and g.phase == 0, "four phases make a day")
	check(g.plots[0] == GS.READY, "crop ready next morning")
	g.tap_plot(0)
	check(g.grain == 3 and g.plots[0] == GS.EMPTY, "harvest gives 3 grain")
	check(g.tap_plot(99) == "Invalid plot", "invalid plot handled")

	var a = GS.new()
	a.feed_animal(0)
	check(a.fed[0] == false, "cannot feed without grain")
	a.grain = 2
	a.feed_animal(0)
	check(a.fed[0] == true and a.grain == 1, "feeding costs 1 grain")
	for i in 4:
		a.next_phase()
	check(a.milk == 2 and a.fed[0] == false, "fed cow gives 2 milk")

	var m = GS.new()
	m.milk = 2
	m.eggs = 3
	m.grain = 5
	m.sell_goods()
	check(m.coins == 6 + 13 and m.grain == 3 and m.milk == 0, "market sale math")

	var l = GS.new()
	l.finish_lesson(true)
	l.finish_lesson(true)
	check(l.coins == 9 and l.knowledge == 1, "lesson rewards only once a day")

	var f = GS.new()
	f.join_festival()
	check(f.joy == 0, "no festival on day 1")
	f.day = 5
	f.phase = 3
	f.join_festival()
	f.join_festival()
	check(f.joy == 10 and f.coins == 11, "festival joined once")

	var h = GS.new()
	h.coins = 0
	for i in 4:
		h.next_phase()
	check(h.coins == GS.SEED_COST, "no soft-lock without coins")

	var s = GS.new()
	s.tap_plot(1)
	s.grain = 4
	var t = GS.new()
	t.from_dict(s.to_dict())
	check(t.plots[1] == GS.SEEDED and t.coins == s.coins and t.grain == 4, "save/load roundtrip")
	t.from_dict({"plots": [1, 2], "fed": [true]})
	check(t.plots.size() == GS.PLOT_COUNT and t.fed.size() == GS.ANIMALS.size(), "bad save data repaired")


func _test_content() -> void:
	var C = load("res://scripts/content.gd")
	check(C.FLAVOR.size() == 4, "four flavor lines")
	check(C.LESSONS.size() >= 6, "at least 6 lessons")
	var ok := true
	for l in C.LESSONS:
		if not (l.has("q") and l.has("options") and l.has("answer") and l.has("why")):
			ok = false
		elif l["options"].size() != 3 or int(l["answer"]) < 0 or int(l["answer"]) > 2:
			ok = false
	check(ok, "all lessons well formed")


func _test_main_scene() -> void:
	var packed = load("res://scenes/main.tscn")
	check(packed != null, "main scene loads")
	if packed == null:
		return
	var inst = packed.instantiate()
	root.add_child(inst)
	await process_frame
	check(inst.get_child_count() > 0, "main scene builds its UI")
	inst.call("_on_plot_pressed", 0)
	inst.call("_on_animal_pressed", 0)
	inst.call("_on_market_pressed")
	inst.call("_open_lesson")
	inst.call("_on_next_pressed")
	await process_frame
	check(inst.state.day >= 1, "buttons run without errors")
	inst.queue_free()
