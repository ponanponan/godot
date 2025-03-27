extends Node

const SYMBOLS = ["🍒", "🍋", "🔔", "⭐", "💎", "🍀", "7️⃣"]
const BET_AMOUNT = 100
const TARGET_RTP = 0.99

# 每個圖案的固定獎金（不重複）
var fixed_rewards = {
	"🍒": 100,
	"🍋": 500,
	"🔔": 1000,
	"⭐": 1500,
	"💎": 2000,
	"🍀": 3000,
	"7️⃣": 5000
}

var reward_weights := {     # 權重（固定）
	"🍒": 50.0,
	"🍋": 30.0,
	"🔔": 20.0,
	"⭐": 10.0,
	"💎": 5.0,
	"🍀": 3.0,
	"7️⃣": 1.0
}

var payout_table := {}
var hit_count := {}
var total_bet := 0
var total_return := 0
var win_pool := []

var SIMULATION_COUNT := 100  # 可調整的模擬次數
var REEL_COUNT := 3  # 可調整的滾輪數

func _ready():
	randomize()
	assign_rewards()
	prepare_win_pool()
	simulate_spins(SIMULATION_COUNT)

func assign_rewards():
	payout_table.clear()
	hit_count.clear()
	for s in SYMBOLS:
		var key = ""
		for i in range(REEL_COUNT):
			key += s
		payout_table[key] = fixed_rewards[s]
		hit_count[key] = 0

# 根據權重與 RTP 準備一個獎池，下注時從池中抽出中獎或未中獎
func prepare_win_pool():
	win_pool.clear()

	var total_weight := 0.0
	for s in SYMBOLS:
		total_weight += reward_weights[s]

	var expected_total_return = TARGET_RTP * BET_AMOUNT
	var expected_hit_rate = expected_total_return / get_average_reward()

	var total_entries := 10000
	var win_entries := int(total_entries * expected_hit_rate)
	var lose_entries := total_entries - win_entries

	# 將中獎條目依據權重分配
	for s in SYMBOLS:
		var portion = reward_weights[s] / total_weight
		var count = int(portion * win_entries)
		for i in range(count):
			var key = ""
			for j in range(REEL_COUNT):
				key += s
			win_pool.append(key)

	# 加入未中獎條目（"XXX" 表示 miss）
	for i in range(lose_entries):
		win_pool.append("XXX")

	win_pool.shuffle()

func get_average_reward() -> float:
	var sum = 0.0
	var total = 0.0
	for s in SYMBOLS:
		sum += reward_weights[s] * fixed_rewards[s]
		total += reward_weights[s]
	return sum / total

func simulate_spins(times: int):
	total_bet = 0
	total_return = 0
	# 不清空 hit_count，保留 assign_rewards() 內部建立的 key

	for i in range(times):
		total_bet += BET_AMOUNT
		var result = win_pool[randi() % win_pool.size()]
		if result != "XXX":
			hit_count[result] = hit_count.get(result, 0) + 1
			if payout_table.has(result):
				total_return += payout_table[result]

	var rtp = float(total_return) / float(total_bet) * 100.0
	print("\n== 模擬結果 ==")
	print("模擬次數：", times)
	print("總下注：", total_bet)
	print("總回報：", total_return)
	print("RTP：", rtp, "%")

	print("\n== 三連中獎統計 ==")
	var total_hits = 0
	for key in payout_table.keys():
		var count = hit_count.get(key, 0)
		total_hits += count
		var chance = float(count) / float(times) * 100.0
		print("%s : 中獎 %d 次，機率 %.4f%%" % [key, count, chance])

	# 加上未中獎統計
	var miss_count = times - total_hits
	var miss_chance = float(miss_count) / float(times) * 100.0
	print("未中獎 : 次數 %d，機率 %.4f%%" % [miss_count, miss_chance])
