extends RefCounted

# Exact producer descriptions are compiled once, never guessed from obsolete
# skill_power columns. Static stat phrases are recognized but not applied twice.
const PROFILES = {
	"出生时，数量+1": {"extra_spawn": 1},
	"远程": {},
	"占领地块时，生命+1": {"capture_hp": 1},
	"死亡时，金币+1~2": {"death_gold": 2},
	"占领地块时，金币+1~2": {"capture_gold": 2},
	"被击杀时，击杀者+1/+1": {"feed_killer": true},
	"速度减半": {},
	"存活8秒后，变为攻击额外提升1点的青蛙": {"interval": "transform", "once": true},
	"击杀时，生命+1": {"kill_hp": 1},
	"友军出生进行召唤时，攻击+1": {"ally_spawn_attack": 1},
	"出生时，数量+1；远程": {"extra_spawn": 1},
	"存活8秒，金币+1~5": {"interval": "gold", "once": true},
	"受到伤害时，对伤害来源造成1点伤害": {"thorns": 1},
	"速度减半；受到伤害-1": {"reduction": 1},
	"跳跃；跳跃后对落地单元格内敌人造成1点伤害": {"jump": 2, "landing_damage": 1},
	"召唤时，立刻提高随机2个友军各3点生命": {"spawn": "ally_hp"},
	"额外攻击1个敌人": {"extra_targets": 1},
	"出生时，我方1个随机建筑生命+5": {"spawn": "building_hp"},
	"远程；群体光环：所有友军攻击+1/生命+1": {"aura": "stats"},
	"暴击光环：暴击率+20%；暴击伤害+100%": {"aura": "critical"},
	"为1格内友军承受伤害": {"guard": true},
	"跳跃光环：每只我方动物首次跳跃时，生命值+2": {"aura": "jump"},
	"我方2个随机建筑攻击+1": {"spawn": "building_attack"},
	"占领时，金币+1~5且生命+3": {"capture_gold": 5, "capture_hp": 3},
	"额外攻击2个敌人": {"extra_targets": 2},
	"移动方式为跳跃，且跳跃后生命+2": {"jump": 2, "landing_hp": 2},
	"阵亡时，对随机远程造成10点伤害": {"death_ranged": 10},
	"远程；攻击距离+1": {},
	"速度翻倍": {},
	"受到伤害-1": {"reduction": 1},
	"移动方式为跳跃，且跳跃距离+1": {"jump": 3},
	"每存活8秒，攻击+1/生命+2": {"interval": "grow"},
	"召唤时，对最高攻击力敌人造成6点伤害": {"spawn": "strongest_damage"},
	"远程；速度翻倍": {},
	"移动方式为冲锋": {"charge": true},
	"远程；弹射+1": {"bounce": 1},
	"击杀时，掠夺5金币": {"plunder": 5},
	"攻击造成溅射效果": {"splash": true},
	"跳跃；击杀时，攻击+1/生命+3": {"jump": 2, "kill_attack": 1, "kill_hp": 3},
	"攻击时，生命+2": {"attack_hp": 2},
	"生命值高于敌人时，受到该敌人伤害减半": {"higher_hp_guard": true},
	"每隔8秒，提高攻击力最高我方动物10生命": {"interval": "strongest_hp"},
	"在我方地块时，暴击率+50%；暴击后提高1攻击": {"home_crit": 0.5, "crit_attack": 1},
	"闪避+50%": {"dodge": 0.5},
	"远程；弹射+2": {"bounce": 2},
	"攻击+10，但每次攻击后减少3攻击，最低为0": {"attack_decay": 3},
	"为周围友军承受伤害": {"guard": true},
	"每隔8秒，对生命值最低敌人造成10点伤害": {"interval": "lowest_damage"},
	"击杀时，对3个随机敌人各造成5点伤害": {"kill_chain": true},
	"攻击不满血的动物时，必然暴击": {"wounded_crit": true},
	"击杀时，获得其最大生命值": {"absorb_hp": true},
	"攻击后，目标当前生命值减半": {"halve_hp": true},
	"攻击造成溅射效果；受到伤害-1": {"splash": true, "reduction": 1},
	"受到伤害-1；在敌方地块时，暴击率+80%": {"reduction": 1, "enemy_crit": 0.8},
	"远程；攻击造成穿透效果": {"pierce": true},
	"为周围友军承受伤害；受到伤害-2": {"guard": true, "reduction": 2},
}

static func compile_text(text: String) -> Dictionary:
	var clean = text.strip_edges()
	if not PROFILES.has(clean):
		push_error("Unsupported producer animal skill: " + clean)
		return {"unsupported": clean}
	return PROFILES[clean].duplicate(true)
