# TooltipKit

Shared tooltip checks for WoW Forever. Other addons ask this library what a tooltip is, and add lines in one pass before the game shows the tip.

LibStub name: `TooltipKit-1.0`. The same library is also `_G.TooltipKit`.

Repository: https://github.com/SultonMRP/TooltipKit

## Install

Unzip `TooltipKit` into `Interface\AddOns`. Enable it. Addons that list `## OptionalDeps: TooltipKit` load it first when it is enabled. They still run if it is turned off.

## What it does

- Tells an item tooltip from a spell, aura, unit, world object, minimap tip, or XLoot loot row.
- Treats secret values as unreadable.
- `On(kind, fn)` uses the tooltip script when that script exists, and a `TooltipDataProcessor` post-call only when the script does not.
- `AddLine` does not call `GameTooltip:Show()`. A line added after the tooltip is already on screen is refused.
- `Companion(host, key)` is a second tooltip under a host that owns its own layout. State is kept off the host tooltip.

GatherNotify and ToolTip IDs use this library.
