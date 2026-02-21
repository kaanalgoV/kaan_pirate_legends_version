# Pirate Legends — Anfänger-Insel Full Design

## Datum: 2026-02-21

## Überblick

Vollständige Anfänger-Insel mit Fokus auf die Licht-Frucht (Lux/Pika Pika no Mi), Haki-System, einzigartigem Dark-Gradient-Glow HUD, und Player-Retention Features.

## 1. Die 6 Lux-Attacken

| Taste | Name | Typ | Dmg | CD | Animation |
|---|---|---|---|---|---|
| 1 | Light Beam | Beam 60 Studs | 35 | 4s | Finger-Pistole → Laser |
| 2 | Light Kick | Dash-Hit 30 Studs | 40 | 5s | Sprint → Tritt |
| 3 | Jewels of Light | AoE R15, 3 Ticks | 30 | 8s | Hände hoch → Kugeln regnen |
| 4 | Yata Mirror | Teleport 50 Studs | 0 | 6s | Blitz-Flash → Teleport |
| 5 | Amaterasu | Charged Beam 80 Studs | 60 | 15s | 1s Charge → Massivstrahl |
| 6 | Light Barrage | Multi-Hit 8x | 15 | 12s | Rapid Punches → KB |

Jede Attacke hat: Cast-Animation (Motor6D), VFX, 3D HUD-Icon, Sound.

## 2. Haki-System

- H-Taste aktiviert bei >= 50% Energie
- Observation Haki: 3D Aura (dunkel lila/schwarz)
- Haki-Dodge: Ghost-Afterimage bei perfektem Timing
- +20% Dmg Boost während aktiv
- Drain: 3/s aktiv, Regen: 2/s inaktiv
- Gain: +3 Schaden geben, +1.5 Schaden nehmen, +5 Dodge

## 3. HUD — Dark Gradient Glow

- Schwarzer bis dunkelblauer Gradient-Hintergrund
- Neon-Glow Ränder (goldgelb für Lux)
- 6 Ability-Slots mit rotierenden 3D-Modellen (ViewportFrame)
- Cooldown: dunkle Scheibe über 3D-Modell
- Haki-Bar: lila Gradient, pulsiert bei >= 50%
- HP-Bar, Guard-Bar, Haki-Energy-Bar

## 4. Anfänger-Insel Layout

- Dorfplatz (Spawn, NPC-Begrüßung)
- Hafen (Piratenschiff, Waver-Verleih U-Taste)
- Markt (Shop-NPCs)
- Trainingsplatz (Dummies)
- 1v1 Arena (Best-of-3 PvP)
- 3v3 Arena (Team PvP)
- Gacha-Platz (Truhe für Devil Fruit Pulls)

## 5. Player Retention

- Daily Login Gems
- Training Challenges ("Treffe 10 Light Beams" → Gems)
- PvP Leaderboard (Dorfplatz)
- NPC Dialoge (Story, Tips)
- Waver-Rennen (Cloud-Flieger Parcours)

## 6. 3D Assets (Tripo AI)

- Piratenhaus, Schatztruhe, Teufelsfrucht, NPC, Palme, Schiff, Waver
- Haki Aura, Light Beam, Light Kick, Jewels, Yata Mirror, Divine Beam, Barrage
- Markt-Stall, PvP Arena, Haki Dodge Afterimage

## 7. Technische Architektur

Client: CombatController, HakiController, HudController, MovementController, WaverController, VFXUtil, AbilityAnimator, InputController
Server: CombatService, HakiService, PlayerStateService, ArenaService, GachaService, DataService
Shared: Config, CombatConfig, FruitConfig (nur Lux), HakiConfig, Enums, Util
