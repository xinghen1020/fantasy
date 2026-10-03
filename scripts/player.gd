@tool
extends CharacterBody3D

## 俯视角玩家基座：XZ 平面八方向走/跑 + 动作系统宿主（缝 A 的场景侧）。
## 移动与动作推进集中在 tick()，可被集成测试手动推进，不依赖场景树帧驱动。

## 命中结算信号；顿帧等反馈由 main.tscn 连到 Feedback 节点
signal hit_landed(damage: int)

const WALK_SPEED := 3.0
const RUN_SPEED := 6.0
const TURN_SPEED := 12.0
# 区分走/跑动画的速度容差
const ANIM_SPEED_EPSILON := 0.1

const ANIM_IDLE := "standard/Idle"
const ANIM_WALK := "standard/Walk"
const ANIM_SPRINT := "standard/Sprint"

# hurtbox 所在物理层（层 3），命中判定查询只找这一层
const HURTBOX_MASK := 4

## 缝 A：动作承诺规则机（纯逻辑）
var machine := CombatStateMachine.new()

# 本次挥击是否已结算（一段判定只结算一次）
var _hit_consumed := true
# 当前意图动画；招式动画短于整招、播完（current_animation 变空）时靠它避免重播
var _anim_intent := ""

# 角色动画播放器（FBX 实例内部的 AnimationPlayer）
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var hitbox: Area3D = $Hitbox
@onready var hitbox_shape: CollisionShape3D = $Hitbox/CollisionShape3D


func _ready() -> void:
	machine.phase_changed.connect(_on_phase_changed)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if Input.is_action_just_pressed("attack"):
		request_light_attack()
	tick(delta)
	update_animation()


## 外部入口：轻攻击输入。游戏中由 attack 输入调用，集成测试直接调用。
## 派生/缓冲规则在状态机内（票03）：自由态起手、窗口内派生、窗口外缓冲。
func request_light_attack() -> void:
	machine.notify_light_pressed()


## 推进一帧：动作状态机 → 移动/前冲 → 命中结算。
func tick(delta: float) -> void:
	machine.tick(delta)
	if machine.is_locked():
		# 攻击期间锁死走跑，位移由招式前冲沿面朝方向提供（用户故事 9）
		velocity = global_transform.basis.z * machine.lunge_speed()
	else:
		var move_input := Input.get_vector("left", "right", "up", "down")
		var running := Input.is_action_pressed("shift")
		var speed := RUN_SPEED if running else WALK_SPEED
		var direction := Vector3(move_input.x, 0.0, move_input.y)
		velocity = direction * speed
		if direction != Vector3.ZERO:
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), TURN_SPEED * delta)
	move_and_slide()
	_resolve_hits()


## 切换走路/跑步/待机/招式动画。按意图去重：招式动画（0.43s）短于整招（0.82s），
## 非循环动画播完后 current_animation 变空，不能据此重播第二遍挥砍。
func update_animation() -> void:
	if animation_player == null:
		return
	var anim := ANIM_IDLE
	if machine.is_locked():
		anim = machine.current_animation()
	elif velocity.length_squared() > 0.01:
		anim = ANIM_SPRINT if velocity.length() > WALK_SPEED + ANIM_SPEED_EPSILON else ANIM_WALK
	if anim == "":
		return
	if _anim_intent == anim:
		return
	_anim_intent = anim
	animation_player.play(anim)


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == CombatStateMachine.Phase.ACTIVE:
		_hit_consumed = false


## 缝 B：判定段用 hitbox 形状对 hurtbox 层做物理空间查询，重叠即结算。
## 用直接查询而非 Area 回调：手动 tick 下判定确定，不依赖物理帧步进。
func _resolve_hits() -> void:
	if machine.phase != CombatStateMachine.Phase.ACTIVE or _hit_consumed:
		return
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = hitbox_shape.shape
	params.transform = hitbox_shape.global_transform
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = HURTBOX_MASK
	var results := get_world_3d().direct_space_state.intersect_shape(params, 8)
	for result in results:
		var area: Area3D = result.collider
		if not area.is_in_group("hurtbox"):
			continue
		_hit_consumed = true
		area.get_parent().take_hit(machine.damage())
		hit_landed.emit(machine.damage())
		return
