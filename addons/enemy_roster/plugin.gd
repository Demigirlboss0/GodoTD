@tool
extends BaseRosterPlugin

## Enemy Roster Plugin

func get_schema_path() -> String:
	return "res://addons/enemy_roster/enemy_schema.tres"

func get_panel_title() -> String:
	return "Enemy Roster"
