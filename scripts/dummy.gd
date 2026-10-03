@tool
extends StaticBody3D

## 木桩：不移动、不还手的静态验证目标（CONTEXT.md：Dummy）。
## take_hit 结算伤害并触发受击闪白。血量归零后重置属票 07，本票只扣血。
## @tool + 外部可读的 flash_count：编辑器内测试套件需要脚本可运行。

signal damaged(amount: int, remaining: int)

@export var max_hp := 100

var hp := 100
## 受击闪白次数，测试断言用
var flash_count := 0

@onready var _mesh: MeshInstance3D = $MeshInstance3D

var _flash_material: StandardMaterial3D


func _ready() -> void:
	hp = max_hp
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(0.2, 1.0, 0.3, 0.55)


func take_hit(damage: int) -> void:
	hp = maxi(hp - damage, 0)
	flash_count += 1
	damaged.emit(damage, hp)
	_flash()


## 受击闪白：短暂叠加无光照半透明白材质。
func _flash() -> void:
	_mesh.material_overlay = _flash_material
	get_tree().create_timer(0.12).timeout.connect(_unflash)


func _unflash() -> void:
	if is_instance_valid(_mesh):
		_mesh.material_overlay = null
