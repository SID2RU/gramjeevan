extends RefCounted
## Pure game logic for GramJeevan (no UI), so it can be tested headless.

const EMPTY := 0
const SEEDED := 1
const WATERED := 2
const READY := 3
const PLOT_COUNT := 9
const SEED_COST := 5
const HARVEST_REWARD := 12

var day: int = 1
var coins: int = 10
var plots: Array = []


func _init() -> void:
	reset()


func reset() -> void:
	day = 1
	coins = 10
	_reset_plots()


func _reset_plots() -> void:
	plots = []
	for i in PLOT_COUNT:
		plots.append(EMPTY)


func tap_plot(i: int) -> String:
	if i < 0 or i >= plots.size():
		return "Invalid plot"
	match plots[i]:
		EMPTY:
			if coins < SEED_COST:
				return "Not enough coins for seeds"
			coins -= SEED_COST
			plots[i] = SEEDED
			return "Planted seeds"
		SEEDED:
			plots[i] = WATERED
			return "Watered the crop"
		WATERED:
			return "Crop is growing. Wait for tomorrow"
		READY:
			plots[i] = EMPTY
			coins += HARVEST_REWARD
			return "Harvested! +%d coins" % HARVEST_REWARD
	return "Nothing to do"


func next_day() -> void:
	day += 1
	var active := 0
	for i in plots.size():
		if plots[i] == WATERED:
			plots[i] = READY
		if plots[i] != EMPTY:
			active += 1
	# Village help: never let the player get stuck without seed money.
	if coins < SEED_COST and active == 0:
		coins = SEED_COST


func to_dict() -> Dictionary:
	return {"day": day, "coins": coins, "plots": plots}


func from_dict(d: Dictionary) -> void:
	day = maxi(1, int(d.get("day", 1)))
	coins = maxi(0, int(d.get("coins", 10)))
	var p = d.get("plots", [])
	if p is Array and p.size() == PLOT_COUNT:
		plots = []
		for v in p:
			plots.append(clampi(int(v), EMPTY, READY))
	else:
		_reset_plots()
