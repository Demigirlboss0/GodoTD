@tool
extends BaseRosterPlugin

## Tower Roster Plugin

func get_schema_path() -> String:
	return "res://addons/tower_roster/tower_schema.tres"

func get_panel_title() -> String:
	return "Tower Roster"
