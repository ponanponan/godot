extends Node

# ✅ 模擬純 RTP 統計用：不帶動畫、不連 UI，單純數值計算

# 🎯 設定目標 RTP（Return to Player）
const TARGET_RTP := 0.8

# 🌀 自動執行的次數
const AUTO_RUNS := 1000

# 🔁 批次模擬參數
const BATCH_COUNT := 5         # 要跑幾組
const SPINS_PER_BATCH := AUTO_RUNS  # 每組模擬幾次（可自訂或用 AUTO_RUNS）

# 💵 可選的下注額度（依照使用者需求調整）
const BET_OPTIONS := [100, 200, 500, 1000, 2000, 5000, 10000]

# 📊 累積總投注與總返還
var total_bet := 0
var total_return := 0

# 📈 統計中獎與未中獎次數
var win_count := 0
var lose_count := 0

# 🧮 各下注金額的次數統計
var bet_stats := {}

# 🏆 各圖案中獎次數統計
var win_stats := {}

# 🎲 隨機數產生器
var rng := RandomNumberGenerator.new()

# 🎰 所有可能的圖案
const SYMBOLS := ["joker", "grape", "cherry", "seven", "bar", "watermelon", "crown", "diamond"]

# 💰 每種圖案的獎勵倍率（以 100 為單位基準）
var symbol_rewards = {
	"cherry": 50,
	"grape": 100,
	"seven": 200,
	"bar": 300,
	"watermelon": 500,
	"crown": 800,
	"joker": 1000,
	"diamond": 2000
}

# ⚖️ 手動設定的機率百分比（總和不一定是 100）
var manual_percentage = {
	"cherry": 40.0,
	"grape": 20.0,
	"seven": 15.0,
	"bar": 10.0,
	"watermelon": 5.0,
	"crown": 4.0,
	"joker": 4.0,
	"diamond": 2.0
}

# 🎯 實際計算用的圖案出現權重
var reward_weights = {}

# ✅ 初始進入點
func _ready():
	rng.randomize()
	calculate_weights()
	#simulate_spins(AUTO_RUNS)
	simulate_batch(BATCH_COUNT, SPINS_PER_BATCH)
	print_report()

# 📐 將手動百分比轉為比例總和為 1.0 的權重表
func calculate_weights():
	reward_weights.clear()
	var total := 0.0
	for s in SYMBOLS:
		total += manual_percentage[s]
	for s in SYMBOLS:
		reward_weights[s] = manual_percentage[s] / total

# 📊 根據權重計算「理論平均獎勵」
func get_average_reward() -> float:
	var total := 0.0
	for s in SYMBOLS:
		total += reward_weights[s] * symbol_rewards[s]
	return total

# 🎰 產生一筆轉動結果（會依照目前 RTP 是否達標決定是否中獎）
func generate_spin_result() -> Array:
	var expected_total_return := TARGET_RTP * total_bet
	var should_win := total_return < expected_total_return
	if should_win:
		# 🎯 未達標 RTP，給中獎（三格相同）
		var chosen := weighted_random_symbol()
		return [chosen, chosen, chosen]
	else:
		# ❌ RTP 超過，給不重複圖案
		var temp := SYMBOLS.duplicate()
		temp.shuffle()
		return [temp[0], temp[1], temp[2]]

# 🔁 根據權重隨機選擇一個圖案
func weighted_random_symbol() -> String:
	var sum := 0.0
	for s in reward_weights:
		sum += reward_weights[s]
	var r := rng.randf_range(0, sum)
	var accum := 0.0
	for s in reward_weights:
		accum += reward_weights[s]
		if r <= accum:
			return s
	return SYMBOLS[0]  # fallback

# 🌀 執行多次模擬轉動
func simulate_spins(times: int):
	for i in range(times):
		var bet_amount: int = BET_OPTIONS.pick_random()
		bet_stats[bet_amount] = bet_stats.get(bet_amount, 0) + 1  # ✅ 累計下注次數
		total_bet += bet_amount
		var result := generate_spin_result()
		if result[0] == result[1] and result[1] == result[2]:
			var symbol = result[0]
			var payout = symbol_rewards[symbol] * bet_amount / 100
			total_return += payout
			win_count += 1
			win_stats[symbol] = win_stats.get(symbol, 0) + 1
		else:
			lose_count += 1

func simulate_batch(batch_count: int, spins_per_batch: int):
	for i in range(batch_count):
		print("\n==============================")
		print("📦 第 %d 組模擬開始..." % (i + 1))
		
		# 重置所有統計資料
		total_bet = 0
		total_return = 0
		win_count = 0
		lose_count = 0
		win_stats.clear()
		bet_stats.clear()

		# 執行單組模擬
		simulate_spins(spins_per_batch)

		# 印出該組報告
		print_report()


# 📋 印出模擬報告
func print_report():
	var total := win_count + lose_count
	print("\n📈 模擬報告")
	print("🎯 中獎次數: %d | 未中獎: %d | 中獎率: %.2f%%" % [win_count, lose_count, 100.0 * win_count / total])
	print("💰 總投注: %d | 總返還: %d | RTP: %.2f%%" % [total_bet, total_return, 100.0 * total_return / total_bet])
	print("🏆 中獎圖案統計:")
	for s in win_stats.keys():
		print("  %s : %d 次" % [s, win_stats[s]])

	print("\n🧾 下注金額統計:")
	for bet in BET_OPTIONS:
		var count: int = bet_stats.get(bet, 0)
		print("  $%d : %d 次" % [bet, count])
