extends Camera3D

## 固定俯角跟随相机：只随目标平移，自身从不旋转。

@export var target_path: NodePath
# 相机相对目标的空间偏移，决定跟随距离与俯角
@export var follow_offset := Vector3(0.0, 9.0, 6.3)

var _target: Node3D

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		push_warning("CameraRig: target_path 未设置或无效，相机不会跟随")

func _physics_process(_delta: float) -> void:
	if _target == null:
		return
	global_position = _target.global_position + follow_offset
