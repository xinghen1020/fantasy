@tool
extends CharacterBody3D

## 俯视角玩家基座：XZ 平面八方向走/跑。
## 移动逻辑集中在 tick()，可被集成测试手动推进，不依赖场景树帧驱动。

const WALK_SPEED := 3.0
const RUN_SPEED := 6.0
const TURN_SPEED := 12.0
# 区分走/跑动画的速度容差
const ANIM_SPEED_EPSILON := 0.1

const ANIM_IDLE := "standard/Idle"
const ANIM_WALK := "standard/Walk"
const ANIM_SPRINT := "standard/Sprint"

# 角色动画播放器（FBX 实例内部的 AnimationPlayer）
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	tick(delta)
	update_animation()

## 推进一帧移动逻辑：读输入 → 速度 → 位移 → 朝向。
func tick(delta: float) -> void:
	var move_input := Input.get_vector("left", "right", "up", "down")
	var running := Input.is_action_pressed("shift")
	var speed := RUN_SPEED if running else WALK_SPEED
	var direction := Vector3(move_input.x, 0.0, move_input.y)
	velocity = direction * speed
	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), TURN_SPEED * delta)
	move_and_slide()

## 切换走路/跑步/待机动画。公开给测试与后续动作系统复用。
func update_animation() -> void:
	if animation_player == null:
		return
	var anim := ANIM_IDLE
	if velocity.length_squared() > 0.01:
		anim = ANIM_SPRINT if velocity.length() > WALK_SPEED + ANIM_SPEED_EPSILON else ANIM_WALK
	if animation_player.current_animation != anim:
		animation_player.play(anim)
