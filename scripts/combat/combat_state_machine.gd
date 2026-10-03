class_name CombatStateMachine
extends RefCounted

## 缝 A：动作承诺规则机。纯逻辑模块，不依赖场景树。
## 输入：招式事件 + tick() 推进的时间；输出：当前招式、当前阶段、前冲速度。
## 阶段机：自由 → 前摇（锁死，拒绝一切取消）→ 判定 → 后摇 → 自由。
## 派生窗口、输入缓冲、翻滚（票 03/05）在此规则机上扩展。

## 阶段切换信号；宿主（玩家）在判定段开判定、退出时收判定。
signal phase_changed(new_phase: int)

enum Phase { FREE, WINDUP, ACTIVE, RECOVERY }

var phase: int = Phase.FREE
var current_move_name := ""

var _move: Dictionary = {}
var _phase_elapsed := 0.0


## 发起招式。仅在自由状态接受；前摇/判定/后摇内一律拒绝（动作承诺）。
## 派生与缓冲是票 03 的事，当前所有非自由输入都直接拒绝。
func start_attack(move_name: String) -> bool:
	if phase != Phase.FREE:
		return false
	var move: Dictionary = MoveTable.get_move(move_name)
	if move.is_empty():
		return false
	_move = move
	current_move_name = move_name
	_phase_elapsed = 0.0
	_set_phase(Phase.WINDUP)
	return true


## 推进一帧阶段计时。时间只从 tick 进来，测试可手动推。
func tick(delta: float) -> void:
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
		Phase.RECOVERY:
			_set_phase(Phase.FREE)


func current_animation() -> String:
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
