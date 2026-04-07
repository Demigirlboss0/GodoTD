# GodoTD - User Manual

Editor plugins for managing enemy and tower data resources in tower defense games.

## Installation

1. Copy the `addons/` folder into your Godot project's root directory
2. Enable both plugins in **Project > Project Settings > Plugins**
3. "Enemy Roster" and "Tower Roster" panels will appear at the bottom of the editor

## Overview

Both plugins provide a split-panel interface:
- **Left Panel**: List of all resources
- **Right Panel**: Form for creating/editing entries
- **Settings Panel**: Configure output directory, resource types, and known tags

---

# Enemy Roster

## Creating Your First Enemy

1. Click **+ Add Enemy** in the left panel
2. Fill in the enemy details (see below)
3. Click **Save** to create the resource file

## Form Fields

### Basic Info
| Field | Description |
|-------|-------------|
| **Enemy Name** | Display name for the enemy |
| **Filename** | Name of the .tres file (auto-generated from enemy name) |
| **Max Health** | Enemy health points |
| **Speed** | Movement speed |
| **Damage** | Damage dealt to player/waves |

### Visuals
The Visuals section lets you define key-value pairs for visual resources:
- **Key**: Identifier (e.g., "body", "sprite")
- **Value**: Texture2D (2D mode) or Mesh (3D mode)

Click **+ Add Visual** to add a new key-value pair.

### Rewards
Rewards are dynamically generated based on your **Resource Types** (configured in Settings). Each resource type becomes a reward field when the enemy is defeated.

### Tags
Enter tags to define which towers can target this enemy:
- Press Enter after typing to add a tag
- Unknown tags (not in the known list) are highlighted in yellow but will be added automatically

---

# Tower Roster

## Creating Your First Tower

1. Click **+ Add Tower** in the left panel
2. Fill in the tower details (see below)
3. Click **Save** to create the resource file

## Form Fields

### Basic Info
| Field | Description |
|-------|-------------|
| **Tower Name** | Display name for the tower |
| **Filename** | Name of the .tres file (auto-generated from tower name) |

### Stats
| Field | Description |
|-------|-------------|
| **Range** | Attack range in units |
| **Damage** | Damage per hit |
| **Fire Rate** | Attacks per second |
| **Pierce** | Number of targets hit per shot |
| **Multishot** | Number of projectiles per attack |
| **Traversal Time** | Time for projectile to reach target |
| **Attack Style** | LINEAR or RADIAL |
| **Projectile Scene** | PackedScene for the projectile |

### Visuals
The Visuals section lets you define key-value pairs for visual resources:
- **Key**: Identifier (e.g., "body", "barrel")
- **Value**: Texture2D (2D mode) or Mesh (3D mode)

Click **+ Add Visual** to add a new key-value pair.

### Costs
Costs are dynamically generated based on your **Resource Types** (configured in Settings). Each resource type becomes a cost field.

### Target Tags
Enter tags to filter which enemies the tower can target:
- Press Enter after typing to add a tag
- Unknown tags (not in the known list) are highlighted in yellow but will be added automatically

---

# Settings

Click the **gear icon** to open Settings for each plugin.

## Project Mode
- **2D**: Visual resources are Textures
- **3D**: Visual resources are Meshes

## Output Directory
The folder where resources are saved:
- Enemy Roster default: `res://enemies/`
- Tower Roster default: `res://towers/`

## Resource Types
Define what currencies/resources can be earned/spent:
- Click **+ Add Resource Type** to add new types
- Each type becomes a reward field (enemies) or cost field (towers)
- Click **X** to remove a type

## Known Tags
Predefined tags that won't trigger warnings:
- Click **X** to remove a tag from the known list

---

# Features

## Auto-naming
When you change a name, the filename automatically derives from it (Title Case + "Data" / "TowerData")

## Duplicate Filename Warning
If you try to save with a filename that already exists, you'll be prompted to overwrite or cancel

## Delete Confirmation
Deleting shows a confirmation dialog to prevent accidental deletion

## Auto-refresh
Lists update automatically when you save, add, or remove entries

---

# Using Resources in Game Code

```gdscript
# Load an enemy
var enemy = load("res://enemies/GoonBotEnemyData.tres") as EnemyData
print(enemy.max_health)

# Load a tower
var tower = load("res://towers/ArrowTowerData.tres") as TowerData
print(tower.damage)

# Check attack style
if tower.attack_style == TowerData.AttackStyle.RADIAL:
    print("Radial attack!")
```

---

# File Structure

The plugins create these files in your output directories:

```
enemies/
├── EnemyData.gd          # Generated base class
├── YourEnemyData.tres   # Your enemies
└── ...

towers/
├── TowerData.gd          # Generated base class
├── YourTowerData.tres   # Your towers
└── ...
```

The `.gd` scripts are auto-generated based on your resource types and project mode.

---

# Troubleshooting

**The plugin doesn't appear.**
1. Go to **Project > Project Settings > Plugins**
2. Make sure the plugin is enabled
3. Check the console for any errors

**Entries don't appear in the list.**
- Make sure your output directory exists
- Ensure files end in `.tres`
- Check Godot's output console for errors

**The generated .gd class fails to generate.**
- Ensure the output directory is writable
- Check the output console for error messages