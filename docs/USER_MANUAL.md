# Tower Roster - User Manual

Tower Roster is a Godot 4 editor plugin that provides a form-driven UI for creating and managing tower data resources for your tower defense game.

## Installation

1. Copy the `tower_roster` folder into your Godot project's `addons/` directory
2. Enable the plugin in **Project > Project Settings > Plugins**
3. A "Tower Roster" panel will appear at the bottom of the editor

## Getting Started

When you first open the plugin, you'll see a split-panel interface:

- **Left Panel**: List of all tower resources
- **Right Panel**: Form for creating/editing towers

### Creating Your First Tower

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

## Settings

Click the **gear icon** next to "Tower List" to open Settings.

### Project Mode

- **2D**: Visual resources are Textures
- **3D**: Visual resources are Meshes

### Output Directory

The folder where tower resources are saved (default: `res://Towers/`)

### Resource Types

Define what currencies/resources towers can cost:
- Click **+ Add Resource Type** to add new types
- Each type becomes a cost field on towers
- Click **X** to remove a type (with confirmation if towers use it)

### Known Tags

Predefined tags that won't trigger warnings:
- Click **X** to remove a tag from the known list

## Features

### Auto-naming

When you change the Tower Name, the Filename automatically derives from it (Title Case + "TowerData")

### Duplicate Filename Warning

If you try to save a tower with a filename that already exists, you'll be prompted to overwrite or cancel

### Delete Confirmation

Deleting a tower shows a confirmation dialog to prevent accidental deletion

### Auto-refresh

The tower list updates automatically when you save, add, or remove towers

## File Structure

The plugin creates these files in your output directory:

```
Towers/
├── TowerData.gd          # Generated base class
├── BasicTowerData.tres   # Your first tower
└── ...
```

The `TowerData.gd` script is auto-generated based on your resource types and project mode.

## Tips

- Use consistent naming for visual keys (e.g., "body", "turret", "projectile")
- Add commonly used resource types (Gold, Wood, Stone) in Settings
- Use BLACKLIST target mode to exclude certain enemy types instead of whitelisting
- The plugin automatically scans for existing .tres files in the output directory

## FAQ

### Troubleshooting

**The plugin doesn't appear. What do I do?**
1. Go to **Project > Project Settings > Plugins**
2. Make sure Tower Roster is enabled
3. Check the console for any errors

**Towers don't appear in the list.**
- Make sure your output directory exists (default: `res://Towers/`)
- Ensure tower files end in `.tres`
- Check Godot's output console for errors

**TowerData.gd fails to generate.**
- Ensure the output directory is writable
- Check the output console for error messages

### Advanced Usage

**How do I use tower resources in my game code?**

```gdscript
# Load a tower
var tower = load("res://Towers/MyTower.tres") as TowerData

# Access properties
print(tower.damage)
print(tower.range)

# Check attack style
if tower.attack_style == TowerData.AttackStyle.LINEAR:
    print("Linear attack!")
```

**Can I back up or export my towers?**
- Yes! Tower resources are just `.tres` files
- Copy the entire output folder to back up
- No built-in import/export feature

**Can I change the output directory?**
- Yes, via Settings
- Existing towers stay in their original location
- New towers save to the new directory
- You may need to update file paths in your game code

### Limitations

**Is there a limit on resource types or tags?**
- No hard limit - use as many as needed
- Performance may degrade with hundreds of resource types

**What if I delete TowerData.gd?**
- It auto-regenerates on plugin reload
- Existing `.tres` files still work
- Any mismatched properties are handled gracefully

### Integration

**Do I need special setup to load towers?**
- No - just standard resource loading
- Optionally cast to `TowerData` for type safety

**Can other scripts use TowerData?**
- Yes! The generated class has `class_name TowerData`
- Any script can reference it: `var t: TowerData = null`

### Settings

**Where are settings stored?**
- `addons/tower_roster/tower_roster/tower_roster_settings.tres`

**Can I share settings between projects?**
- Yes, copy the `.tres` file
- You may need to update the output directory for each project

**How do I reset settings to defaults?**
- Delete the `tower_roster_settings.tres` file
- The plugin creates a fresh one on next load