extends Control

signal handle_pulled

@onready var handle := $Handle
@onready var slot1 := $Slot1  # 確保名稱與場景匹配
@onready var slot2 := $Slot2
@onready var slot3 := $Slot3

var auto_stop_timer := 3.0  # 自動停止時間
var spinning := false
var symbol_weights = {}  # 存儲符號機率

# RTP 計算 - 設定 97% RTP 的機率分佈
const RTP_TARGET := 0.97
const SYMBOLS = [
	{"name": "diamond", "payout": 100},
	{"name": "crown", "payout": 50},
	{"name": "watermelon", "payout": 25},
	{"name": "bar", "payout": 10},
	{"name": "seven", "payout": 5},
	{"name": "cherry", "payout": 2}
]

func _ready():
	handle_pulled.connect(_on_handle_pulled)
	set_symbol_weights(calculate_rtp_weights(RTP_TARGET))  # 設定符合 97% RTP 的機率

func calculate_rtp_weights(target_rtp: float) -> Dictionary:
	var total_payout := 0.0
	var weights := {}
	for symbol in SYMBOLS:
		var probability = (target_rtp / symbol["payout"])  # 依據 RTP 計算機率
		total_payout += probability
		weights[symbol["name"]] = probability
	
	# 正規化機率，使總和為 1
	var normalization_factor = 1.0 / total_payout
	for key in weights.keys():
		weights[key] *= normalization_factor
	
	print("🎰 計算後的機率: ", weights)
	return weights

func set_symbol_weights(weights: Dictionary):
	if weights.size() == 0:
		print("❌ 錯誤: symbol_weights 是空的，請檢查機率計算")
		return
	
	symbol_weights = weights
	print("✅ 機率已分配至所有滾輪: ", symbol_weights)
	
	slot1.set_symbol_weights(weights)
	slot2.set_symbol_weights(weights)
	slot3.set_symbol_weights(weights)

func _on_handle_pressed() -> void:
	if spinning:
		return  # 防止多次觸發
	spinning = true
	var tween = get_tree().create_tween()
	tween.tween_property(handle, "rotation_degrees", -12, 0.2)
	tween.tween_property(handle, "rotation_degrees", 0, 0.2)

	emit_signal("handle_pulled")
	
	# 設定 3 秒後自動停止，但如果玩家手動按下，則重新計時
	var timer := get_tree().create_timer(auto_stop_timer)
	timer.timeout.connect(stop_spinning)

func _on_handle_pulled():
	slot1.start_spinning()
	slot2.start_spinning()
	slot3.start_spinning()
	
	# 等待所有滾輪結束
	await slot1.spin_finished
	await slot2.spin_finished
	await slot3.spin_finished
	
	stop_spinning()  # 確保所有滾輪完成後才停止
	spinning = false

func stop_spinning():
	if !spinning:
		return  # 防止重複停止
	
	# 確保滾輪停止時對齊符號
	slot1.stop_at_correct_position()
	slot2.stop_at_correct_position()
	slot3.stop_at_correct_position()
	spinning = false
	print("✅ 滾輪停止，對齊完成")
