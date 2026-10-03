@tool
extends MeshInstance3D

## 顿帧参照物：匀速往返移动的方块。
## 真顿帧（命中，全局 Engine.time_scale=0）时它跟着停；角色的"动画播完后摇定格"
## 是局部现象，它不停——用它区分真假顿帧（票08 手感调参的观察基准）。

const RANGE_MIN := -3.0
const RANGE_MAX := 3.0
const SPEED := 1.5

var _direction := 1.0


func _physics_process(delta: float) -> void:
	var x := position.x + _direction * SPEED * delta
	if x >= RANGE_MAX:
		x = RANGE_MAX
		_direction = -1.0
	elif x <= RANGE_MIN:
		x = RANGE_MIN
		_direction = 1.0
	position.x = x
