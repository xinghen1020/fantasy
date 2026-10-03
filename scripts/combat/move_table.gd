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
		# 跃进下劈终结技：助跑(0-0.4)→腾空(0.4-0.6)→下劈落地(0.6-0.85)→地面收势(0.85-2.0)
		# 三段按剪辑实际打击时刻排布，总长 2.0s = 剪辑长度，不掐帧
		"animation": "standard_2/Sword_Regular_C",
		# 剪辑自带地面收势，后摇延续本剪辑，置空即可
		"recovery_animation": "",
		"windup": 0.55,
		"active": 0.3,
		"recovery": 1.15,
		"damage": 16,
		"lunge_speed": 2.0,
		"next": {},
	},
}


static func get_move(move_name: String) -> Dictionary:
	return MOVES.get(move_name, {})
