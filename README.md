# GodoTD - Enemy & Tower Roster Plugins

Godot 4 editor plugins for managing enemy and tower data resources in tower defense games.

## Features

### Enemy Roster
- **Visual Form Editor** - Create and edit enemy data through an intuitive UI
- **Dynamic Rewards** - Define custom resource types (gold, points, etc.)
- **Visual Assets** - Link textures (2D) or meshes (3D) to enemies
- **Target Tags** - Define which towers can target specific enemies
- **Auto-generated Class** - EnemyData.gd is automatically created based on your settings

### Tower Roster
- **Visual Form Editor** - Create and edit tower data through an intuitive UI
- **Dynamic Costs** - Define custom resource types (gold, wood, etc.)
- **Visual Assets** - Link textures (2D) or meshes (3D) to towers
- **Target Tags** - Define which enemies each tower can target
- **Auto-generated Class** - TowerData.gd is automatically created based on your settings

## Installation

1. Copy the `addons/` folder into your Godot project's root directory
2. Enable both plugins in **Project > Project Settings > Plugins**
3. "Enemy Roster" and "Tower Roster" panels will appear at the bottom of the editor

## Quick Start

### Enemy Roster
1. Click **+ Add Enemy** to create a new enemy
2. Fill in name, stats, visuals, and rewards
3. Click **Save** to create the resource
4. Use `load("res://enemies/YourEnemy.tres")` in your game code

### Tower Roster
1. Click **+ Add Tower** to create a new tower
2. Fill in name, stats, visuals, and costs
3. Click **Save** to create the resource
4. Use `load("res://towers/YourTower.tres")` in your game code

## Documentation

See [docs/USER_MANUAL.md](docs/USER_MANUAL.md) for detailed usage instructions.

## License

MIT License - see [LICENSE](LICENSE) for details.