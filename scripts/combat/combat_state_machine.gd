class_name CombatStateMachine
extends RefCounted

## 缝 A：动作承诺规则机。纯逻辑模块，不依赖场景树。
## 输入：轻/重/滚输入事件 + tick() 推进的时间；输出：当前招式、当前阶段、前冲速度。
## 阶段机：自由 → 前摇（锁死，拒绝一切取消）→ 判定 → 后摇（=派生窗口）→ 自由。
## 连段（票03）：后摇段开放的派生窗口内按数据表切换下一招；窗口外的输入进单槽
## 缓冲，窗口开启瞬间消费，无派生则弃置（连段到头不循环、无鬼魂输入）。

## 阶段切换信号；宿主（玩家）在判定段开判定、退出时收判定。
signal phase_changed(new_phase: int)

enum Phase { FREE, WINDUP, ACTIVE, RECOVERY }

## 缓冲生命期：窗口开启时距按下超过该时长的输入视为陈旧丢弃。
## 防御性上限（当前所有招的前摇+判定 < 0.5s，正常流程必先被消费）。
const BUFFER_LIFETIME := 0.5

var phase: int = Phase.FREE
var current_move_name := ""

var _move: Dictionary = {}
var _phase_elapsed := 0.0
var _time := 0.0

# 单槽输入缓冲：只保留最新一次输入，新输入覆盖旧输入（票03）
var _buffered_kind := ""
var _buffer_time := 0.0


## 玩家输入入口：轻攻击键。自由态起手连段第 1 段；后摇段（派生窗口）直接派生；
## 前摇/判定段进单槽缓冲，窗口开启时消费。
func notify_light_pressed() -> void:
	_notify_kind_pressed("light")


## 直接起手指定招式。仅自由态可用（动作承诺：其余阶段拒绝）。
## 派生与缓冲走 notify_* 入口；保留此 API 供测试与未来系统（如切招）使用。
func start_attack(move_name: String) -> bool:
	if phase != Phase.FREE:
		return false
	return _begin_move(move_name)


## 推进一帧阶段计时，并在派生窗口开启时消费缓冲。时间只从 tick 进来。
func tick(delta: float) -> void:
	_time += delta
	if phase == Phase.FREE:
		return
	_phase_elapsed += delta
	var duration: float = _move[_phase_key()]
	if _phase_elapsed < duration:
		return
	_phase_elapsed -= duration  # 保留溢出时间，节奏不丢帧
	match phase:
		Phase.WINDUP:
			_set_phase(Phase.ACTIVE)
		Phase.ACTIVE:
			_set_phase(Phase.RECOVERY)
			_consume_buffer()
		Phase.RECOVERY:
			_set_phase(Phase.FREE)


## 当前阶段应播的动画：前摇/判定段播挥砍，后摇段播收招（数据表未配则延续挥砍）。
func current_animation() -> String:
	if phase == Phase.RECOVERY and _move.get("recovery_animation", "") != "":
		return _move.get("recovery_animation")
	return _move.get("animation", "")


func damage() -> int:
	return _move.get("damage", 0)


## 招式前冲速度：前摇+判定段沿面朝方向位移，进入后摇即收势站定。
func lunge_speed() -> float:
	if phase == Phase.WINDUP or phase == Phase.ACTIVE:
		return _move.get("lunge_speed", 0.0)
	return 0.0


## 动作是否锁死走跑输入。
func is_locked() -> bool:
	return phase != Phase.FREE


func _notify_kind_pressed(kind: String) -> void:
	match phase:
		Phase.FREE:
			var root: String = MoveTable.INPUT_ROOTS.get(kind, "")
			if root != "":
				_begin_move(root)
		Phase.RECOVERY:
			_derive(kind)
		_:
			# 前摇/判定段：动作承诺，拒绝一切取消，输入进单槽缓冲
			_buffered_kind = kind
			_buffer_time = _time


## 派生窗口（后摇段）内按数据表切换下一招；表上无派生则静默丢弃（连段到头）。
func _derive(kind: String) -> void:
	var next_move: String = _move.get("next", {}).get(kind, "")
	if next_move != "":
		_begin_move(next_move)


## 窗口开启瞬间消费缓冲：有派生则起手下一招；无派生或输入已陈旧则弃置。
## 消费/弃置后缓冲必空——缓冲从不会带进自由态（无鬼魂输入）。
func _consume_buffer() -> void:
	if _buffered_kind == "":
		return
	var kind := _buffered_kind
	_buffered_kind = ""
	if _time - _buffer_time > BUFFER_LIFETIME:
		return
	_derive(kind)


func _begin_move(move_name: String) -> bool:
	var move: Dictionary = MoveTable.get_move(move_name)
	if move.is_empty():
		return false
	_move = move
	current_move_name = move_name
	_phase_elapsed = 0.0
	_set_phase(Phase.WINDUP)
	return true


func _phase_key() -> String:
	match phase:
		Phase.WINDUP:
			return "windup"
		Phase.ACTIVE:
			return "active"
		Phase.RECOVERY:
			return "recovery"
	return ""


func _set_phase(new_phase: int) -> void:
	phase = new_phase
	if new_phase == Phase.FREE:
		_move = {}
		current_move_name = ""
	phase_changed.emit(new_phase)
