extends RefCounted
## GramJeevan game logic (no UI) so it can be tested headless.

const EMPTY := 0
const SEEDED := 1
const WATERED := 2
const READY := 3
const PLOT_COUNT := 6
const SEED_COST := 2
const HARVEST_GRAIN := 3
const GRAIN_KEEP := 3
const PHASE_NAMES := ["Morning", "Afternoon", "Evening", "Night"]
const ANIMALS := ["Cow", "Hens", "Goat"]
const PRODUCTS := ["milk", "eggs", "milk"]
const PRODUCT_AMOUNT := [2, 3, 1]
const PRICE_GRAIN := 2
const PRICE_MILK := 3
const PRICE_EGGS := 1
const FESTIVAL_EVERY := 5
const START_COINS := 6
const LESSON_REWARD := 3
const FESTIVAL_COINS := 5
const FESTIVAL_JOY := 10

var day: int = 1
var phase: int = 0
var coins: int = 6
var grain: int = 0
var milk: int = 0
var eggs: int = 0
var knowledge: int = 0
var joy: int = 0
var plots: Array = []
var fed: Array = []
var lesson_done: bool = false
var festival_joined: bool = false


func _init() -> void:
	reset()


func reset() -> void:
	day = 1
	phase = 0
	coins = START_COINS
	grain = 0
	milk = 0
	eggs = 0
	knowledge = 0
	joy = 0
	lesson_done = false
	festival_joined = false
	plots = []
	for i in PLOT_COUNT:
		plots.append(EMPTY)
	fed = []
	for i in ANIMALS.size():
		fed.append(false)


func is_festival_day() -> bool:
	return day % FESTIVAL_EVERY == 0


func tap_plot(i: int) -> String:
	if i < 0 or i >= plots.size():
		return "Invalid plot"
	match plots[i]:
		EMPTY:
			if coins < SEED_COST:
				return "Not enough coins for seeds (need %d)" % SEED_COST
			coins -= SEED_COST
			plots[i] = SEEDED
			return "Sowed seeds for %d coins" % SEED_COST
		SEEDED:
			plots[i] = WATERED
			return "Watered the crop. It grows by morning."
		WATERED:
			return "Already watered. Wait for tomorrow."
		READY:
			plots[i] = EMPTY
			grain += HARVEST_GRAIN
			return "Harvested %d grain!" % HARVEST_GRAIN
	return "Nothing to do"


func feed_animal(i: int) -> String:
	if i < 0 or i >= ANIMALS.size():
		return "Invalid animal"
	if fed[i]:
		return "%s is already fed." % ANIMALS[i]
	if grain < 1:
		return "You need 1 grain to feed the %s." % ANIMALS[i]
	grain -= 1
	fed[i] = true
	return "%s is fed and happy. Gives %s tomorrow." % [ANIMALS[i], PRODUCTS[i]]


func sell_goods() -> String:
	var surplus: int = maxi(0, grain - GRAIN_KEEP)
	var earned: int = milk * PRICE_MILK + eggs * PRICE_EGGS + surplus * PRICE_GRAIN
	if earned <= 0:
		return "Nothing to sell yet."
	coins += earned
	milk = 0
	eggs = 0
	grain -= surplus
	return "Sold goods at the market for %d coins." % earned


func finish_lesson(correct: bool) -> String:
	if lesson_done:
		return "Lesson already done today."
	lesson_done = true
	if correct:
		coins += LESSON_REWARD
		knowledge += 1
		return "+%d coins, +1 knowledge" % LESSON_REWARD
	return "Try again tomorrow."


func join_festival() -> String:
	if not is_festival_day() or phase != 3:
		return "There is no festival right now."
	if festival_joined:
		return "You already joined tonight's festival."
	festival_joined = true
	joy += FESTIVAL_JOY
	coins += FESTIVAL_COINS
	return "Music, lamps and sweets! +%d joy, +%d coins" % [FESTIVAL_JOY, FESTIVAL_COINS]


func next_phase() -> String:
	phase += 1
	if phase < PHASE_NAMES.size():
		return "%s begins." % PHASE_NAMES[phase]
	phase = 0
	day += 1
	var report := ""
	var active := 0
	for i in plots.size():
		if plots[i] == WATERED:
			plots[i] = READY
		if plots[i] != EMPTY:
			active += 1
	for i in ANIMALS.size():
		if fed[i]:
			var amount: int = PRODUCT_AMOUNT[i]
			if PRODUCTS[i] == "milk":
				milk += amount
			else:
				eggs += amount
			report += "%s gave %d %s. " % [ANIMALS[i], amount, PRODUCTS[i]]
		fed[i] = false
	lesson_done = false
	festival_joined = false
	if coins < SEED_COST and grain == 0 and milk == 0 and eggs == 0 and active == 0:
		coins = SEED_COST
		report += "The village helped you with %d coins. " % SEED_COST
	return "Day %d begins. %s" % [day, report]


func to_dict() -> Dictionary:
	return {
		"day": day, "phase": phase, "coins": coins, "grain": grain,
		"milk": milk, "eggs": eggs, "knowledge": knowledge, "joy": joy,
		"plots": plots, "fed": fed,
		"lesson_done": lesson_done, "festival_joined": festival_joined,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	day = maxi(1, int(d.get("day", 1)))
	phase = clampi(int(d.get("phase", 0)), 0, PHASE_NAMES.size() - 1)
	coins = maxi(0, int(d.get("coins", START_COINS)))
	grain = maxi(0, int(d.get("grain", 0)))
	milk = maxi(0, int(d.get("milk", 0)))
	eggs = maxi(0, int(d.get("eggs", 0)))
	knowledge = maxi(0, int(d.get("knowledge", 0)))
	joy = maxi(0, int(d.get("joy", 0)))
	var p = d.get("plots", [])
	if p is Array and p.size() == PLOT_COUNT:
		plots = []
		for v in p:
			plots.append(clampi(int(v), EMPTY, READY))
	var f = d.get("fed", [])
	if f is Array and f.size() == ANIMALS.size():
		fed = []
		for v in f:
			fed.append(bool(v))
	lesson_done = bool(d.get("lesson_done", false))
	festival_joined = bool(d.get("festival_joined", false))
