class_name MoveTable

## 招式数据表：每个招式声明动画、三段时长（前摇/判定/后摇）、伤害、前冲速度、派生表。
## 加新招只改这里，不改状态机（spec 用户故事 21）。
## 数值全部为占位，票 08 手感调参在这里改。

const LIGHT_ATTACK_1 := "light_attack_1"
const LIGHT_ATTACK_2 := "light_attack_2"
const LIGHT_ATTACK_3 := "light_attack_3"

## 输入类型 → 该类连段的起手招
const INPUT_ROOTS := {
	"light": LIGHT_ATTACK_1,
}

## 派生表写在每招的 "next" 里：输入类型 → 下一招。无键/空表即不可派生（连段到头）。
const MOVES := {
	LIGHT_ATTACK_1: {
		"animation": "standard_2/Sword_Regular_A",
		"recovery_animation": "standard_2/Sword_Regular_A_Rec",
		"windup": 0.25,
		"active": 0.12,
		"recovery": 0.45,
		"damage": 10,
		"lunge_speed": 3.0,
		"next": {"light": LIGHT_ATTACK_2},
	},
	LIGHT_ATTACK_2: {
		"animation": "standard_2/Sword_Regular_B",
		"recovery_animation": "standard_2/Sword_Regular_B_Rec",
		"windup": 0.25,
		"active": 0.12,
		"recovery": 0.45,
		"damage": 12,
		"lunge_speed": 3.0,
		"next": {"light": LIGHT_ATTACK_3},
	},
	LIGHT_ATTACK_3: {
		# 库内 Sword_Regular_C（2.0s）实为"助跑→跃起→摔倒"剪辑，不是挥砍，弃用；
		# 换用同族节奏的单发打击 Melee_Hook（0.47s，对比 A 0.43 / B 0.53）
		"animation": "standard_2/Melee_Hook",
		# 库内 Hook 无独立 _Rec，暂复用 A 的收招
		"recovery_animation": "standard_2/Sword_Regular_A_Rec",
		"windup": 0.25,
		"active": 0.12,
		"recovery": 0.5,
		"damage": 16,
		"lunge_speed": 2.0,
		"next": {},
	},
}


static func get_move(move_name: String) -> Dictionary:
	return MOVES.get(move_name, {})
