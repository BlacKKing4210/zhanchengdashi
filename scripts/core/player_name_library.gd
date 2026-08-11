extends RefCounted

const PLAYER_NAMES = [
	"晨雾旅人",
	"松果队长",
	"月湾渔火",
	"山雀邮差",
	"薄荷汽水",
	"橘子海",
	"纸船远航",
	"风铃草",
	"夜航星",
	"栗子骑士",
	"晴天收集者",
	"海盐云朵",
	"林间信使",
	"青柠苏打",
	"晚风放映机",
	"雾岛来客",
	"雨后蜗牛",
	"北岸灯塔",
	"小熊软糖",
	"星河散步",
	"枫叶车站",
	"猫尾草",
	"云朵邮局",
	"夏日柚子",
]


static func name_for_index(index: int) -> String:
	if PLAYER_NAMES.is_empty():
		return "旅行者"
	return String(PLAYER_NAMES[posmod(index, PLAYER_NAMES.size())])


static func random_available_name(rng: RandomNumberGenerator, reserved_names: Dictionary = {}) -> String:
	var candidates = []
	for raw_name in PLAYER_NAMES:
		var player_name = String(raw_name)
		if not reserved_names.has(player_name):
			candidates.append(player_name)
	if candidates.is_empty():
		return "%s%d" % [name_for_index(rng.randi_range(0, PLAYER_NAMES.size() - 1)), rng.randi_range(10, 99)]
	return String(candidates[rng.randi_range(0, candidates.size() - 1)])
