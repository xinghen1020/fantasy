@tool
extends McpTestSuite

## 票02 缝B集成测试：轻攻击命中木桩 → 扣血 + 闪白 + 顿帧被调用。
## 断言外部行为：木桩 damaged 信号/hp/flash_count、feedback 记录、玩家动画。

const MAIN_SCENE := preload("res://scene/main.tscn")
const TICK := 1.0 / 60.0
# 整招约 0.82s（50 tick），余量充足
const MAX_SWING_FRAMES := 240

var _main: Node


func suite_name() -> String:
	return "attack_dummy"


func suite_setup(_ctx: Dictionary) -> void:
	# 编辑器的 InputMap 不含项目自定义动作（仅游戏运行时加载），补上以便模拟输入
	if not InputMap.has_action("attack") or not InputMap.has_action("left"):
		InputMap.load_from_project_settings()


func teardown() -> void:
	for action in ["attack", "left", "right", "up", "down", "shift"]:
		Input.action_release(action)
	# 防御：绝不让顿帧的时间缩放泄漏进编辑器
	Engine.time_scale = 1.0


func _spawn_arena() -> void:
	_main = track(MAIN_SCENE.instantiate())
	EditorInterface.get_edited_scene_root().add_child(_main)


func _player() -> CharacterBody3D:
	return _main.get_node("Player")


func _dummy() -> StaticBody3D:
	return _main.get_node("Dummy")


func _feedback() -> Node:
	return _main.get_node("Feedback")


## 玩家放到攻击距离（1.1m）内并面向木桩
func _face_dummy() -> void:
	var dummy := _dummy()
	var to_dummy: Vector3 = dummy.global_position - _player().global_position
	_player().global_position = dummy.global_position - to_dummy.normalized() * 1.1
	_player().rotation.y = atan2(to_dummy.x, to_dummy.z)


## 发起轻攻击并推 tick，直到木桩 damaged 信号触发；返回是否命中
func _swing_until_hit(hit_info: Array) -> bool:
	_dummy().damaged.connect(func(amount: int, _remaining: int) -> void:
		hit_info.append(amount))
	_player().request_light_attack()
	for i in MAX_SWING_FRAMES:
		_player().tick(TICK)
		_player().update_animation()
		if not hit_info.is_empty():
			return true
	return false


func test_light_attack_damages_dummy() -> void:
	_spawn_arena()
	_face_dummy()
	var hit_info: Array = []
	assert_true(_swing_until_hit(hit_info), "攻击判定段应命中近距离木桩")
	assert_eq(hit_info[0], MoveTable.MOVES[MoveTable.LIGHT_ATTACK_1]["damage"], "伤害应来自招式数据表")
	assert_true(_dummy().hp < _dummy().max_hp, "木桩应扣除血量")
	assert_gt(_dummy().flash_count, 0, "命中应触发受击闪白")
	assert_gt(_feedback().last_hit_stop_duration, 0.0, "命中应触发顿帧")
	assert_eq(_player().animation_player.current_animation, MoveTable.MOVES[MoveTable.LIGHT_ATTACK_1]["animation"], "攻击期间应播放数据表指定的招式动画")


func test_one_swing_hits_once() -> void:
	_spawn_arena()
	_face_dummy()
	var hit_info: Array = []
	_dummy().damaged.connect(func(amount: int, _remaining: int) -> void:
		hit_info.append(amount))
	_player().request_light_attack()
	for i in MAX_SWING_FRAMES * 2:
		_player().tick(TICK)
		_player().update_animation()
	assert_eq(hit_info.size(), 1, "一段判定只应结算一次命中")
	assert_true(_dummy().hp < _dummy().max_hp, "木桩应恰好被扣一次血")


func test_locked_movement_has_no_lateral_input() -> void:
	_spawn_arena()
	_face_dummy()
	var player := _player()
	var facing_before := player.rotation.y
	Input.action_press("left")  # 攻击期间尝试走位
	player.request_light_attack()
	# 10 tick = 0.167s，仍在前摇（0.25s）内
	for i in 10:
		player.tick(TICK)
		player.update_animation()
	assert_eq(player.rotation.y, facing_before, "攻击期间方向输入不应转向")
	assert_eq(player.machine.phase, CombatStateMachine.Phase.WINDUP, "仍应处于前摇段")
	var expected: Vector3 = player.global_transform.basis.z * player.machine.lunge_speed()
	assert_true(player.velocity.distance_to(expected) < 0.01, "攻击期间速度应只有面朝方向的前冲")


func test_whiff_does_no_damage() -> void:
	_spawn_arena()
	var player := _player()
	# 背对木桩（木桩在 +X 方向 2m 处，玩家面朝 -X）
	player.global_position = Vector3(1.1, 0, 0)
	player.rotation.y = atan2(-1.0, 0.0)
	var hit_info: Array = []
	_dummy().damaged.connect(func(amount: int, _remaining: int) -> void:
		hit_info.append(amount))
	player.request_light_attack()
	for i in MAX_SWING_FRAMES:
		player.tick(TICK)
		player.update_animation()
	assert_true(hit_info.is_empty(), "背对木桩挥空不应造成伤害")
	assert_eq(_dummy().hp, _dummy().max_hp, "挥空后木桩血量应完好")


func test_attack_animation_plays_once_per_swing() -> void:
	_spawn_arena()
	_face_dummy()
	var player := _player()
	var attack_anim: String = MoveTable.MOVES[MoveTable.LIGHT_ATTACK_1]["animation"]
	player.request_light_attack()
	var plays := 0
	var was_playing := false
	for i in MAX_SWING_FRAMES:
		player.tick(TICK)
		player.update_animation()
		var playing: bool = player.animation_player.current_animation == attack_anim
		if playing and not was_playing:
			plays += 1
		was_playing = playing
	assert_eq(plays, 1, "招式动画（0.43s）短于整招（0.82s），一次点击只应播放一遍，不可重播第二遍挥砍")
