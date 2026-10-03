@tool
extends Node

## 命中反馈宿主：顿帧（命中瞬间全局暂停数帧，CONTEXT.md：Hit-stop）。
## 反馈是命中结算的副作用，挂在本节点，不侵入状态机（spec）。
## 编辑器内（含测试）只记录不动全局时间，避免冻结编辑器。

const HIT_STOP_DURATION := 0.08  # 占位：约 5 帧，票 08 调参

## 最近一次顿帧时长，0 = 尚未触发（测试断言用）
var last_hit_stop_duration := 0.0

var _frames_left := 0


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _frames_left > 0:
		_frames_left -= 1
		Engine.time_scale = 0.0
	elif Engine.time_scale == 0.0:
		Engine.time_scale = 1.0


## 顿帧入口：游戏内由玩家 hit_landed 信号驱动（main.tscn 连接）。
func on_hit_landed(_damage: int) -> void:
	last_hit_stop_duration = HIT_STOP_DURATION
	if Engine.is_editor_hint():
		return
	# time_scale=0 时物理帧照常回调、delta 归零：世界冻结，按帧数计时解冻
	_frames_left = int(round(HIT_STOP_DURATION * 60.0))
