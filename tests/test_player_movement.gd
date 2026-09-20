@tool
extends McpTestSuite
## 票01 集成测试：3D 玩家基座。
## 断言外部行为：模拟移动输入后玩家位置/朝向发生变化、走/跑两档速度、动画随速度切换。

const PLAYER_SCENE := preload("res://scene/player.tscn")
const MAIN_SCENE := preload("res://scene/main.tscn")

const TICK := 1.0 / 60.0
const FRAMES := 30

# 与编辑器场景里已有的 Player 实例错开出生点，避免胶囊体重叠挡住 move_and_slide
const SPAWN_POS := Vector3(2, 0, 2)

var _spawn_count := 0


func suite_name() -> String:
	return "player3d"


func suite_setup(_ctx: Dictionary) -> void:
	# 编辑器的 InputMap 不含项目自定义动作（仅游戏运行时加载），补上以便模拟输入
	if not InputMap.has_action("left"):
		InputMap.load_from_project_settings()


func teardown() -> void:
	for action in ["left", "right", "up", "down", "shift"]:
		Input.action_release(action)


func _spawn_player(spawn_pos: Vector3 = SPAWN_POS) -> CharacterBody3D:
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	player.position = spawn_pos
	EditorInterface.get_edited_scene_root().add_child(player)
	return track(player)


func _tick_frames(player: CharacterBody3D, frames: int) -> void:
	for i in frames:
		player.tick(TICK)
		player.update_animation()


func test_move_input_changes_position() -> void:
	var player := _spawn_player()
	var start := player.global_position
	Input.action_press("up")
	_tick_frames(player, FRAMES)
	# 编辑器里 move_and_slide 的实际步长随编辑器帧率浮动，位移只断言"发生了变化"
	var displacement := (player.global_position - start).length()
	assert_gt(displacement, 0.05, "模拟移动输入后玩家应产生位移，实际位移 %s" % displacement)
	assert_true(player.global_position.z < start.z, "up 输入应朝 -Z 方向移动")
	assert_gt(absf(player.rotation.y), 0.1, "玩家应转向移动方向")
	assert_true(absf(player.velocity.length() - 3.0) < 0.01, "走路速度应为 3 m/s，实际 %s" % player.velocity.length())


func test_run_is_faster_than_walk() -> void:
	var walker := _spawn_player()
	Input.action_press("up")
	_tick_frames(walker, FRAMES)

	Input.action_release("up")
	# 与仍在场上的 walker 错开出生点，避免胶囊体重叠干扰 move_and_slide
	var runner := _spawn_player(SPAWN_POS + Vector3(3, 0, 0))
	Input.action_press("up")
	Input.action_press("shift")
	_tick_frames(runner, FRAMES)

	assert_true(absf(walker.velocity.length() - 3.0) < 0.01, "走路速度应为 3 m/s，实际 %s" % walker.velocity.length())
	assert_true(absf(runner.velocity.length() - 6.0) < 0.01, "跑步速度应为 6 m/s，实际 %s" % runner.velocity.length())


func test_animation_matches_speed() -> void:
	var player := _spawn_player()
	_tick_frames(player, FRAMES)
	assert_eq(player.animation_player.current_animation, "standard/Idle", "无输入应播放 Idle")

	Input.action_press("up")
	_tick_frames(player, FRAMES)
	assert_eq(player.animation_player.current_animation, "standard/Walk", "走路速度应播放 Walk")

	Input.action_press("shift")
	_tick_frames(player, FRAMES)
	assert_eq(player.animation_player.current_animation, "standard/Sprint", "shift 跑步应播放 Sprint")


func test_main_scene_structure() -> void:
	var main: Node = track(MAIN_SCENE.instantiate())
	var camera := main.find_children("*", "Camera3D", true, false)
	assert_eq(camera.size(), 1, "主场景应含一个相机")
	if camera.size() != 1:
		return
	var cam: Camera3D = camera[0]
	var pitch_deg := rad_to_deg(cam.rotation.x)
	assert_true(pitch_deg <= -50.0 and pitch_deg >= -60.0, "相机俯角应在 50–60°，实际 %s°" % pitch_deg)
	assert_ne(cam.get_script(), null, "相机应挂跟随脚本")
	assert_eq(main.find_children("*", "CharacterBody3D", true, false).size(), 1, "主场景应实例化玩家")
	assert_gt(main.find_children("*", "MeshInstance3D", true, false).size(), 1, "主场景应含地面与参照物")
