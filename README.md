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

## Model controls

On the character sheet, inspect and dressing-room model (when available):

| Input | Behaviour |
| --- | --- |
| Hold left mouse + drag right | Rotate character counterclockwise |
| Hold left mouse + drag left | Rotate character clockwise |
| Mouse wheel up/down | Zoom in/out, clamped to 0.6–3.0× |
| Hold right mouse + drag | Pan model left/right and up/down |

The rotation direction uses **positive** `SetFacing` for a rightward drag. On the target 1.12 client, horizontal movement changes the model's second position coordinate and vertical movement the third; the first (depth) is left untouched. Mouse-wheel zoom remains independent. The original model position/scale are recorded for reset, per frame.

## Commands

- `/ecs` — help
- `/ecs stats on` or `/ecs stats off`
- `/ecs model on` or `/ecs model off` — restores the default turn buttons when disabled
- `/ecs left resist` (or `right resist`) — choose any group for either pane
- `/ecs font 8` — 6–12
- `/ecs reset` — restore each model's original zoom and position

## Compatibility and verification

Version 0.1.1 restores the original left-button drag registration and corrects the right-button pan axes following in-game feedback. This is an extracted **candidate**, not an in-game-tested release. It uses 1.12-style event globals (`this`, `event`, `arg1`) and avoids newer `HookScript` APIs. The model hooks chain previous scripts and check for mouse releases outside the frame. The stats pane is refreshed on equipment, aura, level and character changes. Inspect/dressing-room frames may load later, so model hooks are retried every two seconds.

**Manual checks to do in a real client:** character sheet open/reopen, stat group dropdowns, all five resistances with and without a resistance buff, dual wield hit/crit, dragging in both directions, right-drag pan, wheel zoom, reset, mouse release outside the model, opening Inspect/DressUp after login, and confirming the addon has no side effects when disabled.

## Source and licence

The stat calculation/pane code is adapted from `modules/characterpanel.lua` and the rotation model logic from `modules/qol.lua` at ClassicOverhaul commit `e9f9ee1` (9 November 2026). GPL-3.0-or-later; see the parent repository's `LICENSE` and `NOTICE` for project and component acknowledgements.
