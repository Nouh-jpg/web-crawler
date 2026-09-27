# WEB-CRAWLER

Neon horror spider-crawler shooter for Godot 4.7. Spiders drop from the ceiling. Keep them off the floor. Every fifth wave is a bug swarm: clear it clean and the gun upgrades. The lady scream plays when the house is lost.

Hold fire. Keys `1` `2` `3` switch revolver, pistol, shotgun. `R` reloads. `U` spends parts on the selected gun. The crosshair sticks a little when it is already near a spider. It does not aim for you.

BEST and TODAY are saved on this device (`user://web_crawler.cfg`). TODAY uses the device date as the run seed.

Store steps, package id `com.nouh.webcrawler`, and the page copy are in [docs/LAUNCH.md](docs/LAUNCH.md). Export presets for Windows, Android (AAB), and iOS (Xcode project) are in `export_presets.cfg`. Icons under `assets/icons/` are placeholders.

## Gun-feel playtest

1. Open `scenes/Main.tscn` and play. The Attic banner is up immediately and the first spiders drop within a second.
2. Sweep the revolver across a spider. The gun should track the cursor quickly, with a small sway, and kick back then settle without bouncing.
3. Hold the pistol. Shots should stay on a steady rhythm. Trails should fade out instead of painting the screen. The muzzle flash is a couple of frames.
4. Switch to the shotgun. A centered aim on a nearby spider should land the cone. Pellets stay in a tight fan instead of a wide miss pattern.
5. Kill a normal spider: a short freeze (about two frames), a small camera punch, and a bright spark. Bug spiders freeze for about one frame so a swarm does not lock the game.
6. Let a spider reach the floor. Around six seconds in, a red flash and `SHE HEARD YOU` play the whisper, not the full scream. The scream is still the game-over sting.
7. Reach a multiple of five waves. `BUG SWARM` and the left-count banner should be readable. A clean swarm shows a short upgrade line (`REVOLVER  LV 1` or `NEST TOXIN`). A breach shows `SWARM BROKE IN`.
8. Die. The lady fills the frame with `SHE FOUND YOU`, then the score, the room name, and BEST. Restart and confirm TODAY survived.

Headless check (Godot 4.7 binary on `PATH`):

```
godot --headless --path . --import
godot --headless --audio-driver Dummy --path . --script res://scripts/SmokeTest.gd
```

The smoke script checks the bullet pool, fire interval, shotgun cone, aim stick, recoil settle, hitstop, the four rooms, the lady scream buffer, bug-wave upgrade, and the local save.
