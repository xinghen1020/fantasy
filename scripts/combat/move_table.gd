class_name MoveTable

## 招式数据表：每个招式声明动画、三段时长（前摇/判定/后摇）、伤害、前冲速度。
## 加新招只改这里，不改状态机（spec 用户故事 21）。
## 本票数值全部为占位，票 08 手感调参在这里改。

const LIGHT_ATTACK_1 := "light_attack_1"

const MOVES := {
	LIGHT_ATTACK_1: {
		"animation": "standard_2/Sword_Regular_A",
		"windup": 0.25,
		"active": 0.12,
		"recovery": 0.45,
		"damage": 10,
		"lunge_speed": 3.0,
	},
}


static func get_move(move_name: String) -> Dictionary:
	return MOVES.get(move_name, {})
