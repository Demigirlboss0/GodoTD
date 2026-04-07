# Tower Roster

A Godot 4 editor plugin that provides a form-driven UI for creating and managing TowerData resources for tower defense games.

## Features

- **Visual Form Editor** - Create and edit tower data through an intuitive UI
- **Dynamic Costs** - Define custom resource types (Gold, Wood, etc.)
- **Visual Assets** - Link textures (2D) or meshes (3D) to towers
- **Target Tags** - Define which enemies each tower can target
- **Auto-generated Class** - TowerData.gd is automatically created based on your settings

## Installation

1. Download or clone this repository
2. Copy the `tower_roster` folder into your Godot project's `addons/` directory
3. Enable the plugin in **Project > Project Settings > Plugins**

## Quick Start

1. Click **+ Add Tower** to create a new tower
2. Fill in the tower name, stats, visuals, and costs
3. Click **Save** to create the resource
4. Use `load("res://Towers/YourTower.tres")` in your game code

## Documentation

See [docs/USER_MANUAL.md](docs/USER_MANUAL.md) for detailed usage instructions.

## License

MIT License - see [LICENSE](LICENSE) for details.