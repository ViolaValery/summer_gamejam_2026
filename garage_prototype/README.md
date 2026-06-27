# Garage-Prototyp (Lookup)

Referenz-Szene zum Snappen & Kombinieren von Teilen. **Nicht der finale Code** –
gedacht zum Nachschauen, während du deine erste eigene Szene baust.

Starten: ist als `run/main_scene` eingetragen → einfach **F5**.
(Wenn du deine eigene Szene baust, stell `run/main_scene` in den Projekteinstellungen um.)

## Dateien

| Datei | Inhalt |
|---|---|
| `main.tscn` | Welt: Kamera, Boden, Basis, Palette (Reifen/Rakete/Ballon), HUD |
| `world.gd` | Drag & Drop, Snap-Vorschau, Anhängen (Gelenk) / Verschmelzen |
| `part_editor.gd` | Minimal-HUD (Hinweis + Zurücksetzen) |
| `parts/base.tscn` | die Basis (Chassis), an die alles kommt |
| `parts/wheel.tscn` | Reifen – lose am Gelenk, rollt |
| `parts/balloon.tscn` | Helium-Ballon – `gravity_scale` negativ, schwebt |
| `parts/rocket_boost.tscn` + `.gd` | Rakete – verschmilzt fest, erzeugt Schub |

## Kernkonzepte (zum Wiederverwenden)

- **Sichtbar ≠ Physik:** `CollisionShape2D` (Physik) und `Polygon2D` (Optik) sind getrennt.
- **Körperarten:** `StaticBody2D` (Boden), `RigidBody2D` (alles Bewegliche).
- **Material:** Reibung/Sprungkraft über `PhysicsMaterial`; Schwerkraft pro Körper über `gravity_scale`.
- **Teil = eigene Szene** in `parts/`. Neues Teil: `.tscn` bauen + in `PART_SCENES` (world.gd) eintragen → Palette-Eintrag erscheint von selbst.
- **Lose anhängen:** `PinJoint2D` zwischen zwei `RigidBody2D` (Scharnier).
- **Fest verschmelzen:** `metadata/rigid = true` am Teil → `world.gd` reparentet Form+Optik in die Basis = ein einziger Körper, kein Versatz, kein Wackeln.
- **Snappen:** nur an die Basis, nur innerhalb `SNAP_DISTANCE` (world.gd). Grüner Faden = Vorschau; zu weit weg = Teil fällt frei.

## Wichtige Stolpersteine, die hier schon gelöst sind

- Einen aktiven `RigidBody2D` **nicht** per `.position` zurücksetzen (Physik überschreibt) → beim Reset die Basis frisch neu erzeugen.
- HUD-`Control` auf `mouse_filter = IGNORE`, sonst schluckt es Klicks für die Welt.
- Maus-Loslassen in `_input` (nicht `_unhandled_input`) behandeln, damit es nie verloren geht.
