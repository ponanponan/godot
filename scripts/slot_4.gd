extends Node
const activity_controller = preload("res://scripts/activity_controller.gd")
const sound_player = preload("res://scripts/activeity_sound.gd")

@export var slots: Array[Node]

# ✅ 可調參數
var input_locked := false
var auto_mode := false
const AUTO_RUNS := 100
const TARGET_RTP := 0.97
const BET_OPTIONS := [100, 200, 500, 1000, 2000, 5000, 10000]
#var bet_amount := 100  # 當前下注金額

# 🎰 基本資料
const SYMBOLS: Array[String] = [
	"joker", "grape", "cherry", "seven",
	"bar", "watermelon", "crown", "diamond"
]

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

var manual_percentage = {
	"cherry": 40.0,
	"grape": 20.0,
	"seven": 15.0,
	"bar": 10.0,
	"watermelon": 5.0,
	"crown": 4.0,
	"joker": 104.0,
	"diamond": 2.0
}

# 🎲 控制與統計
var spinning := false
var stopping := false
var active_spins := 0
var auto_count := 0
var reward_weights = {}

var win_count := 0
var lose_count := 0
var win_stats := {}
var total_bet := 0
var total_return := 0

# 🧾 CSV 記錄
var csv_output_path := ""
var csv_file: FileAccess
var round_id := 1
var enable_csv_logging := true
var result_symbols: Array[String] = []
var rng := RandomNumberGenerator.new()

func _ready():
	var user_name = OS.get_environment("USERNAME")
	csv_output_path = "C:/Users/%s/Desktop/godot/slot_result_log.csv" % user_name

	if enable_csv_logging and not FileAccess.file_exists(csv_output_path):
		var csv_file = FileAccess.open(csv_output_path, FileAccess.WRITE)
		if csv_file:
			csv_file.store_line("round,symbol1,symbol2,symbol3,is_win,payout,bet_amount,total_bet,total_return,rtp")
			csv_file.close()

	rng.randomize()
	calculate_weights()

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
	print("📊 計算圖案權重:", reward_weights)

func _input(event):
	if input_locked:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if spinning and not stopping:
			print("🛑 停止所有滾輪")
			stopping = true
			for slot in slots:
				if slot.has_method("stop_spinning"):
					slot.stop_spinning()
			auto_mode = false
		elif not spinning and active_spins == 0:
			print("▶️ 開始旋轉")
			stopping = false
			start_spin()
		else:
			print("⏳ 正在減速中，請稍候...")

func start_spin():
	if spinning:
		return
	spinning = true
	active_spins = slots.size()

	var bet_amount: int = BET_OPTIONS.pick_random()
	total_bet += bet_amount

	var expected_total_return := TARGET_RTP * total_bet
	var should_win := total_return < expected_total_return

	#var result_symbols: Array[String]
	var payout := 0
	var is_win := false

	if should_win:
		var symbol := weighted_random_symbol()
		result_symbols = [symbol, symbol, symbol]
		payout = symbol_rewards[symbol] * bet_amount / 100
		total_return += payout
		is_win = true
		win_count += 1
		win_stats[symbol] = win_stats.get(symbol, 0) + 1
	else:
		var temp := SYMBOLS.duplicate()
		temp.shuffle()
		result_symbols = [temp[0], temp[1], temp[2]]
		lose_count += 1

# 	📄 即時寫入 CSV（開 -> 寫 -> 關）
	if enable_csv_logging:
		var file := FileAccess.open(csv_output_path, FileAccess.READ_WRITE)
		if file:
			file.seek_end()  # ✅ 移動到檔案結尾
			var rtp: float = (float(total_return) / total_bet) * 100.0 if total_bet > 0 else 0.0
			file.store_line("%d,%s,%s,%s,%s,%d,%d,%d,%d,%.2f" % [
				round_id,
				result_symbols[0], result_symbols[1], result_symbols[2],
				str(is_win),
				payout,
				bet_amount,
				total_bet,
				total_return,
				rtp
			])
			file.close()
			round_id += 1


	for i in range(slots.size()):
		var slot = slots[i]
		var symbol: String = result_symbols[i]
		var y_pos = get_symbol_y(symbol)

		if slot.has_method("set_spin_target"):
			slot.set_spin_target(y_pos)

		if slot.has_method("start_spinning"):
			slot.start_spinning()

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
	return SYMBOLS[0]

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

func _exit_tree():
	if csv_file:
		csv_file.close()
