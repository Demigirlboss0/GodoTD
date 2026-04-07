@tool
extends Resource
class_name EnemyData

@export var enemy_name: String = ""
@export var max_health: float = 100.0
@export var speed: float = 100.0
@export var damage: float = 1.0
@export var target_tags: Array[String] = []
@export var visuals: Dictionary = {}
@export var reward_gold: int = 0
