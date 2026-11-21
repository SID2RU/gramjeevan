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


func _init() -> void:
	_test_scripts_parse()
	_test_game_state()
	_test_main_scene()
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
	check(g.coins == 10 and g.day == 1, "initial state")
	check(g.tap_plot(0) == "Planted seeds" and g.coins == 5, "plant costs 5")
	check(g.plots[0] == GS.SEEDED, "plot seeded")
	g.tap_plot(0)
	check(g.plots[0] == GS.WATERED, "plot watered")
	g.next_day()
	check(g.plots[0] == GS.READY and g.day == 2, "crop ready next day")
	g.tap_plot(0)
	check(g.coins == 17 and g.plots[0] == GS.EMPTY, "harvest pays 12")
	check(g.tap_plot(99) == "Invalid plot", "invalid plot handled")
	var h = GS.new()
	h.coins = 0
	h.next_day()
	check(h.coins == GS.SEED_COST, "no soft-lock without coins")
	var s = GS.new()
	s.tap_plot(1)
	var t = GS.new()
	t.from_dict(s.to_dict())
	check(t.plots[1] == GS.SEEDED and t.coins == s.coins, "save/load roundtrip")
	t.from_dict({"plots": [1, 2]})
	check(t.plots.size() == GS.PLOT_COUNT, "bad save data repaired")


func _test_main_scene() -> void:
	var packed = load("res://scenes/main.tscn")
	check(packed != null, "main scene loads")
	if packed == null:
		return
	var inst = packed.instantiate()
	root.add_child(inst)
	check(inst.get_child_count() > 0, "main scene builds its UI")
	inst.queue_free()
