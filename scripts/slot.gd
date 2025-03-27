extends TextureRect

@onready var row := $Row
signal spin_finished  # 當滾輪停止時發送訊號給主腳本

# 🔧 可調整參數區
const SYMBOL_HEIGHT := 80
const TOTAL_SYMBOLS := 8
const MAX_Y := -560
const MIN_Y := 0

const INITIAL_SPEED := 2000
const MIN_SPEED := 200
const DECELERATION_FACTOR := 0.9
const AUTO_STOP_TIME := 3.0
const DECELERATION_DISTANCE := 300
const STOP_THRESHOLD := 100

const MIN_SPIN_CIRCLES := 2      # ✅ 自動情況最少轉幾圈
const MIN_SPIN_CIRCLES_ON_STOP := 1  # ✅ 如果按下停止，也至少要轉幾圈

# 內部變數
var rng = RandomNumberGenerator.new()
var spinning := false
var stopping := false
var speed := 0
var target_y := 0
var stop_timer: SceneTreeTimer = null

# ✅ 計圈專用
var distance_spun := 0.0
var required_distance := 0.0

func _ready():
	rng.randomize()
	row.position.y = MAX_Y
	print("✅ Slot 初始化完成，Row 位置: ", row.position.y)

func set_spin_target(y: int):
	target_y = y
	print(name, " 🎯 接收 target_y: ", target_y)

func start_spinning():
	if spinning:
		return

	spinning = true
	stopping = false
	speed = INITIAL_SPEED
	distance_spun = 0.0
	required_distance = (MIN_SPIN_CIRCLES * TOTAL_SYMBOLS) * SYMBOL_HEIGHT
	print(name, " ▶️ 滾輪開始旋轉，目標停靠點: ", target_y)

	stop_timer = get_tree().create_timer(AUTO_STOP_TIME)
	stop_timer.timeout.connect(stop_spinning)

func _process(delta):
	if spinning:
		var move = speed * delta
		distance_spun += move
		row.position.y += move

		if row.position.y > MIN_Y:
			row.position.y = MAX_Y

		if stopping and distance_spun >= required_distance:
			var distance_to_target = abs(row.position.y - target_y)

			if distance_to_target < DECELERATION_DISTANCE:
				speed = max(MIN_SPEED, speed * DECELERATION_FACTOR)

			if distance_to_target < STOP_THRESHOLD:
				row.position.y = target_y
				speed = 0
				spinning = false
				print("✅ 滾輪停止，位置:", row.position.y)

				# ✅ 等待 1 秒後再發送完成訊號
				await get_tree().create_timer(1.0).timeout
				spin_finished.emit()

func stop_spinning():
	if spinning and not stopping:
		stopping = true
		# ✅ 如果是提早按停，也強制轉滿 MIN_SPIN_CIRCLES_ON_STOP
		required_distance = max(required_distance, (MIN_SPIN_CIRCLES_ON_STOP * TOTAL_SYMBOLS) * SYMBOL_HEIGHT)
		print("🛑 滾輪開始減速，將轉滿至少 %.0f px" % required_distance)
