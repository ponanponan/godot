extends Node
const activity_controller = preload("res://scripts/activity_controller.gd")
const sound_player = preload("res://scripts/activeity_sound.gd")

@export var slots: Array[Node]  # 連接 slot.gd 的節點（滾輪列表）

# 啟用/禁止 空白鍵觸發
var input_locked := false

# ✅ 可調整參數區
var auto_mode := false         # 是否在 _ready() 啟動自動模式
const AUTO_RUNS := 10          # 自動跑幾次
const TARGET_RTP := 0.97       # 目標 RTP（期望的回報率）
const BET_AMOUNT := 100        # 每次下注金額（固定）
const TOTAL_ENTRIES := 10   # 獎池條目總數（中獎 + 未中獎）

# 每個圖案的固定獎金
const SYMBOLS: Array[String] = [
	"joker", "grape", "cherry", "seven",
	"bar", "watermelon", "crown", "diamond"
]

var symbol_rewards = {  # ✅ 有使用：給中獎圖案對應獎金
	"cherry": 50,
	"grape": 100,
	"seven": 200,
	"bar": 300,
	"watermelon": 500,
	"crown": 800,
	"joker": 1000,
	"diamond": 2000
}

# 手動設定圖案出現的百分比（會正規化成權重）
var manual_percentage = {  # ✅ 有使用：用來生成 reward_weights
	"cherry": 40.0,
	"grape": 20.0,
	"seven": 15.0,
	"bar": 10.0,
	"watermelon": 5.0,
	"crown": 4.0,
	"joker": 104.0,
	"diamond": 2.0
}

# ✅ 遊戲運行控制變數
var spinning := false           # ✅ 有使用：表示是否正在旋轉
var active_spins := 0           # ✅ 有使用：用來確認是否所有滾輪已停
var auto_count := 0             # ✅ 有使用：剩下自動輪數
var reward_weights = {}         # ✅ 有使用：由 manual_percentage 算出
var win_pool: Array = []        # ✅ 有使用：預先組合好的結果組合

# ✅ 統計變數
var win_count := 0              # ✅ 有使用：中獎次數
var lose_count := 0             # ✅ 有使用：未中獎次數
var win_stats := {}             # ✅ 有使用：紀錄各圖案中獎次數
var total_bet := 0              # ✅ 有使用：總下注金額
var total_return := 0           # ✅ 有使用：總派彩金額

var stopping := false           # ✅ 有使用：減速過程中避免誤觸空白鍵
var rng := RandomNumberGenerator.new()  # ✅ 有使用：用於抽選獎池結果
var csv_output_path := ""       # ✅ 有使用：CSV 檔案輸出路徑
var pool_index := 0             # ✅ 新增：紀錄目前使用的獎池 ID

func _ready():


	
	# ✅ 動態設定 CSV 輸出路徑
	var user_name = OS.get_environment("USERNAME")
	csv_output_path = "C:/Users/%s/Desktop/godot/slot_rtp_report.csv" % user_name
	
	
	rng.randomize()
	calculate_weights()
	prepare_win_pool()


	# ✅ 立即寫入獎池到 CSV
	write_initial_csv()
	
	
	if slots.is_empty():
		for child in get_children():
			if child.has_method("start_spinning"):
				slots.append(child)

	for slot in slots:
		if slot.has_signal("spin_finished"):
			slot.spin_finished.connect(_on_slot_spin_finished.bind(slot))


	print("✅ 初始化完成")
	if auto_mode:
		start_auto_mode(AUTO_RUNS)

func calculate_weights():
	reward_weights.clear()
	var total_percent := 0.0
	for s in SYMBOLS:
		total_percent += manual_percentage[s]
	for s in SYMBOLS:
		reward_weights[s] = manual_percentage[s] / total_percent
	print("📊 根據手動百分比計算權重:", reward_weights)
	
func prepare_win_pool():
	win_pool.clear()
	var total_weight := 0.0
	for s in SYMBOLS:
		total_weight += reward_weights[s]

	var expected_total_return := TARGET_RTP * BET_AMOUNT
	var expected_hit_rate := expected_total_return / get_average_reward()
	var win_entries := int(TOTAL_ENTRIES * expected_hit_rate)  # ✅ 使用 round 確保精度
	var lose_entries := TOTAL_ENTRIES - win_entries  # ✅ 確保總數正確

	# **累積計算中獎次數**
	var total_generated_wins := 0
	var win_distribution := {}

	for s in SYMBOLS:
		var portion = reward_weights[s] / total_weight
		var count = round(portion * win_entries)  # ✅ 四捨五入
		win_distribution[s] = count
		total_generated_wins += count

	# **修正誤差**
	var error = win_entries - total_generated_wins
	if error != 0:
		print("⚠️ 修正誤差: ", error)

		# 找到最多的符號，進行調整
		var max_symbol = SYMBOLS[0]
		for s in SYMBOLS:
			if win_distribution[s] > win_distribution[max_symbol]:
				max_symbol = s

		win_distribution[max_symbol] += error  # ✅ **修正誤差**

	# 生成中獎組合
	for s in SYMBOLS:
		for i in range(win_distribution[s]):
			win_pool.append([s, s, s])

	# **重新計算 lose_entries**
	lose_entries = TOTAL_ENTRIES - win_pool.size()

	# 生成未中獎（三個不同符號）
	for i in range(lose_entries):
		var temp: Array[String] = SYMBOLS.duplicate()
		temp.shuffle()
		win_pool.append([temp[0], temp[1], temp[2]])

	# **最後檢查並確保條目正確**
	while win_pool.size() < TOTAL_ENTRIES:
		var temp: Array[String] = SYMBOLS.duplicate()
		temp.shuffle()
		win_pool.append([temp[0], temp[1], temp[2]])

	while win_pool.size() > TOTAL_ENTRIES:
		win_pool.pop_back()

	# ✅ 確保數據正確
	print("📦 最終數據 -> 中獎: %d, 未中獎: %d, 總計: %d" % [win_entries, lose_entries, win_pool.size()])


func get_average_reward() -> float:
	var total = 0.0
	var weight = 0.0
	for s in SYMBOLS:
		total += reward_weights[s] * symbol_rewards[s]
		weight += reward_weights[s]
	return total / weight

func _input(event):
	
	if input_locked:
		return  # 忽略所有輸入
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if spinning and not stopping:
			print("🛑 停止所有滾輪")
			stopping = true  # ✅ 進入減速狀態
			for slot in slots:
				if slot.has_method("stop_spinning"):
					slot.stop_spinning()
			auto_mode = false
		elif not spinning and active_spins == 0:
			print("▶️ 開始旋轉")
			stopping = false  # ✅ 重置狀態
			start_spin()
		else:
			print("⏳ 正在減速中，請稍候...")

func start_spin():
	if spinning:
		return
	spinning = true
	active_spins = slots.size()
	total_bet += BET_AMOUNT
	
	pool_index = randi() % win_pool.size()
	var result_symbols = win_pool[pool_index] as Array[String]
	print("🎯 本輪使用獎池 ID: %d → [%s, %s, %s]" % [
		pool_index + 1,  # ✅ 這樣就對應 CSV 行
		result_symbols[0], result_symbols[1], result_symbols[2]
	])

		
		
	var is_win := false
	var payout := 0

	if result_symbols[0] == result_symbols[1] and result_symbols[1] == result_symbols[2]:
		is_win = true
		var win_symbol = result_symbols[0]
		win_count += 1
		win_stats[win_symbol] = win_stats.get(win_symbol, 0) + 1
		payout = symbol_rewards[win_symbol]
		total_return += payout
	else:
		lose_count += 1



	for i in range(slots.size()):
		var slot = slots[i]
		var symbol: String = result_symbols[i]
		var y_pos = get_symbol_y(symbol)

		if slot.has_method("set_spin_target"):
			slot.set_spin_target(y_pos)
			print("🎯 指派給", slot.name, ": ", symbol, " → y: ", y_pos)

		if slot.has_method("start_spinning"):
			slot.start_spinning()

func get_symbol_y(symbol: String) -> int:
	match symbol:
		"joker": return 0
		"crown": return -80
		"watermelon": return -160
		"bar": return -240
		"seven": return -320
		"cherry": return -400
		"grape": return -480
		"diamond": return -560
	return 0
	
	
func _on_slot_spin_finished(slot):
	print("✅", slot.name, "滾輪停止")
	active_spins -= 1

	if active_spins == 0:
		spinning = false
		print("✅ 所有滾輪停止")

		var result_symbols = win_pool[pool_index]

		# 🔐 播放影片前再檢查圖案是否全是 joker
		if result_symbols[0] == "joker" and result_symbols[1] == "joker" and result_symbols[2] == "joker":
			print("🎉 三個都是 joker")
			input_locked = true
			var sound_player_instance = sound_player.new()
			sound_player_instance.play_jackpot(self, func():
				print("✅ 播放完成，現在可以繼續中獎動畫")
			)
			await get_tree().create_timer(2).timeout

			var activity_controller_instance = activity_controller.new()
			activity_controller_instance.play_vedio(self, func():
				print("✅ 影片播放完畢，解鎖操作")
				input_locked = false
			)


		# 📊 自動模式 or 結算報告
		if auto_mode:
			auto_count -= 1
			if auto_count > 0:
				await get_tree().create_timer(0.5).timeout
				start_spin()
			else:
				auto_mode = false
				print_report()
		else:
			print_report()



func print_report():
	var total = win_count + lose_count
	print("\n📈 模擬報告")
	print("🎯 中獎次數: %d | 未中獎: %d | 中獎率: %.2f%%" % [win_count, lose_count, 100.0 * win_count / total])
	print("💰 總投注: %d | 總返還: %d | RTP: %.2f%%" % [total_bet, total_return, 100.0 * total_return / total_bet])
	print("🏆 中獎圖案統計:")
	for s in win_stats.keys():
		print("  %s : %d 次" % [s, win_stats[s]])



func start_auto_mode(times: int):
	if spinning:
		return
	auto_mode = true
	auto_count = times
	start_spin()


func write_initial_csv():
	# 確保檔案路徑有效
	if csv_output_path.is_empty():
		print("❌ CSV 輸出路徑未設定")
		return

	# 打開檔案進行寫入
	var file := FileAccess.open(csv_output_path, FileAccess.WRITE)
	if not file:
		print("❌ 無法寫入 CSV 檔案:", csv_output_path)
		return

	# 寫入標題行
	file.store_line("id,symbol1,symbol2,symbol3,is_win,payout,bet_valid")

	# 變數計算 RTP
	var round_id := 1  # 遊戲局數 ID
	var total_bet: int = 0  # 總下注
	var total_payout: int = 0  # 總派彩
	var total_win: int = 0  # 中獎次數
	var total_lose: int = 0  # 未中獎次數

	# 寫入獎池數據
	for entry in win_pool:
		var is_win: bool = entry[0] == entry[1] and entry[1] == entry[2]
		var payout: int = symbol_rewards.get(entry[0], 0) if is_win else 0  # 計算派彩
		var bet_valid: int = BET_AMOUNT  # 每次下注固定 100

		# 更新 RTP 計算數據
		total_bet += bet_valid
		total_payout += payout
		if is_win:
			total_win += 1
		else:
			total_lose += 1

		# 存入 CSV
		file.store_line("%d,%s,%s,%s,%s,%d,%d" % [round_id, entry[0], entry[1], entry[2], str(is_win), payout, bet_valid])

		# 遊戲局數累加
		round_id += 1

	# **計算 RTP**
	var rtp: float = (float(total_payout) / float(total_bet)) * 100.0 if total_bet > 0 else 0.0
	var win_rate: float = (float(total_win) / float(total_win + total_lose)) * 100.0 if (total_win + total_lose) > 0 else 0.0

	# **加入 RTP 報告**
	file.store_line("")  # 空行分隔
	file.store_line("總投注,總派彩,RTP(%),中獎次數,未中獎次數,中獎率(%)")
	file.store_line("%d,%d,%.2f,%d,%d,%.2f" % [total_bet, total_payout, rtp, total_win, total_lose, win_rate])

	# 關閉檔案
	file.close()
	print("📄 獎池 CSV 已生成:", csv_output_path)



	
