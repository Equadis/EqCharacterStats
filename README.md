# EqCharacterStats

A standalone World of Warcraft **1.12** addon extracted from [Equadis Classic Overhaul](https://github.com/Equadis/ClassicOverhaul). This is **not** the full overhaul: it only adds enhanced character statistics and mouse controls to character model previews.

## Install

Download the repository, rename the extracted folder **EqCharacterStats**, and copy it into `World of Warcraft/Interface/AddOns/`, so that the file `Interface/AddOns/EqCharacterStats/EqCharacterStats.toc` exists. Restart the game.

Do not enable this addon alongside ClassicOverhaul's character-stats and model-drag features, or another addon that controls the same PaperDoll/Inspect/DressUp model frames. Their scripts and stats panes can conflict. Use either standalone EqCharacterStats *or* the corresponding ClassicOverhaul features.

## Stats

The paper doll gets two compact panes, each with a dropdown. Groups:

- `base` — primary attributes, armour
- `melee` — weapon skill, damage, speed, attack power, hit, crit
- `meleeboss` — melee values against boss-level targets
- `ranged` — ranged stats
- `spell` — spell stats
- `schools` — spell-school bonuses
- `defense` — defence, dodge, parry, block
- `defenseboss` — defensive values against boss-level targets
- `resist` — **Arcane, Fire, Frost, Nature, Shadow** resistances

Resistance rows use the **total** returned by `UnitResistance("player", schoolIndex)` after buffs/gear and not a manually summed approximation. Hit/crit extraction retains the original tooltips/gear/talents/aura logic and source explanations. When the client cannot provide a number, it is not silently fabricated.


## Item rarity borders

The original ECO item-quality border system is included in v0.1.3 (from
`ClassicOverhaul/modules/qol.lua`). It tints the **existing Blizzard item-slot
normal texture** rather than drawing a replacement ring, with an optional
`UI-ActionButton-Border` additive glow.

- **Green / uncommon** and higher rarities get their standard WoW quality colours.
- **Common and poor** items retain their normal borders.
- Works on the character paper doll and Inspect; also applies to normal bags
  and bank slots, as in the original ECO implementation.
- Updates when equipped items or bags change, when bags/bank open, and when
  Inspect's item slots finish loading.

Default settings are borders **on**, glow **on**, glow opacity **0.55**.

Commands: `/ecs rarity on|off`, `/ecs glow on|off`, and
`/ecs glowalpha 0.55` (opacity between 0 and 1).

## Model controls

On the character sheet, inspect and dressing-room model (when available):

| Input | Behaviour |
| --- | --- |
| Hold left mouse + drag right | Rotate character counterclockwise |
| Hold left mouse + drag left | Rotate character clockwise |
| Mouse wheel up/down | Centre-origin zoom in/out (camera-depth movement, clamped to the existing wheel range) |
| Hold right mouse + drag | Pan model left/right and up/down |

The stock 1.12 paper doll uses `PlayerModel:SetRotation()` and a `model.rotation` field, which are now used for left-drag (rightward movement increases the angle). Right-drag changes the model's second and third position coordinates (horizontal and vertical) at 10× the previous sensitivity. Mouse-wheel zoom changes the first coordinate (camera depth), leaving model scale intact so the character expands about the view centre instead of growing upward from its feet. The same zoom bounds and wheel step are retained. The original model position/scale are recorded for reset, per frame.

## Commands

- `/ecs` — help
- `/ecs stats on` or `/ecs stats off`
- `/ecs model on` or `/ecs model off` — restores the default turn buttons when disabled
- `/ecs left resist` (or `right resist`) — choose any group for either pane
- `/ecs font 10` — 6–14 (default 10; existing settings increase by 2 pt once)
- `/ecs pan 10` — pan sensitivity from 1–30 (default 10; previously effectively 1)
- `/ecs reset` — restore each model's original zoom and position

## Compatibility and verification

Version 0.1.3 adds ECO rarity-coloured item slot borders and glow. Version 0.1.2 uses the stock 1.12 `SetRotation` codepath and explicit drag start/stop callbacks; changes zoom to camera depth, increases right-drag pan sensitivity to 10, and increases stat fonts by 2 pt. These changes still require a real 1.12 in-game retest. It uses 1.12-style event globals (`this`, `event`, `arg1`) and avoids newer `HookScript` APIs. The model hooks chain previous scripts and check for mouse releases outside the frame. The stats pane is refreshed on equipment, aura, level and character changes. Inspect/dressing-room frames may load later, so model hooks are retried every two seconds.

**Manual checks to do in a real client:** character sheet open/reopen, rarity borders on equipped green/blue/epic items, common/poor border reset, inspecting another player, bag/bank open and item move, toggling glow/borders, stat group dropdowns, all five resistances with and without a resistance buff, dual wield hit/crit, dragging in both directions, right-drag pan, wheel zoom, reset, mouse release outside the model, opening Inspect/DressUp after login, and confirming the addon has no side effects when disabled.

## Source and licence

The stat calculation/pane code is adapted from `modules/characterpanel.lua` and the rotation model logic from `modules/qol.lua` at ClassicOverhaul commit `e9f9ee1` (9 November 2026). GPL-3.0-or-later; see the parent repository's `LICENSE` and `NOTICE` for project and component acknowledgements.
