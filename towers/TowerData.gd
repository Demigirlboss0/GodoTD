extends Resource
class_name TowerData

enum AttackStyle { LINEAR, RADIAL }
enum TargetMode { WHITELIST, BLACKLIST }

@export var tower_name: String = ""
@export var range: float = 10.0
@export var damage: float = 10.0
@export var fire_rate: float = 1.0
@export var pierce: int = 1
@export var multishot: int = 1
@export var projectile_scene: PackedScene
@export var traversal_time: float = 0.0
@export var attack_style: AttackStyle = AttackStyle.LINEAR
@export var target_tags: Array[String] = []
@export var target_mode: TargetMode = TargetMode.WHITELIST
@export var visuals: Dictionary = {}
@export var cost_gold: int = 0
@export var cost_iron: int = 0

const ATTACK_STYLE_NAMES = {
	AttackStyle.LINEAR: "LINEAR",
	AttackStyle.RADIAL: "RADIAL"
}

const TARGET_MODE_NAMES = {
	TargetMode.WHITELIST: "WHITELIST",
	TargetMode.BLACKLIST: "BLACKLIST"
}
