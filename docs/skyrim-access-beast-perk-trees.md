# Skyrim Access: reading the Werewolf and Vampire Lord perk trees

Change request for Skyrim Access (tested against 1.9.3, built Oct 4 2026, runtime 1.7.104).
Written by Josh with analysis of the plugin's log, the vanilla/SkyUI `statsmenu.swf` and the
CommonLibSSE-NG headers the plugin is built on.

## Summary

The skills menu reader (`menu_stats.cpp` / `menu_perks.h`) already does everything needed for the
beast perk trees except one thing: its perk index only covers the eighteen skills. The werewolf
and Vampire Lord trees hang off two other actor values, `kWerewolfPerks` (158) and `kVampirePerks`
(159). Adding those two trees to `BuildIndex` and deriving "the current tree" from the perk that was
found (instead of from a skill ring selection) gives the beast trees the same announcements and
hotkeys as the normal trees: name, description, children, parents, buyable, owned.

## What happens today

Log of one visit to the werewolf tree (Growl is installed, so the perk names are Growl's; the
vanilla tree behaves the same):

```
[perks] BuildIndex done : 18 skills, 469 perks total
[SPEAK]      "Skills, level 7"
[stats] mode change: zoomed=false -> true
[stats] DIAG HEARTBEAT: chosen='Bestial Strength (0/4)' (scale=113.5) | top3: [1] 'Bestial Strength (0/4)' s=113.5 xy=-0,91 ...
[stats] DIAG: now seeing perk='Bestial Strength (0/4)' (scale=113.5)
[stats] DIAG: skip perk='Bestial Strength (0/4)' reason=not_in_index
...
[SPEAK]      "Is this right?, Ok, Cancel"          <- the purchase confirmation box is read fine
[stats] DIAG: now seeing perk='Bestial Strength (1/4)' (scale=113.5)
[stats] DIAG: skip perk='Bestial Strength (1/4)' reason=not_in_index
[stats] DIAG: now seeing perk='Bury the Beast' (scale=113.4)
[stats] DIAG: skip perk='Bury the Beast' reason=not_in_index
```

So in the beast tree:

* zoom detection works (`mode change: zoomed=...`), the menu opens zoomed in and the player can
  zoom out to a card view and back;
* the centred-perk detection works (the largest `PerkName*` label is found, scale 113.5, which is
  above the 110 threshold);
* the rank suffix is present exactly as in the normal trees (`(0/4)`, `(1/4)`);
* every perk is dropped with `reason=not_in_index`, so nothing is spoken and hotkeys 1 to 4 have
  nothing to work on;
* on open, the ring announcement "Skills, level 7" is spoken although there is no ring. The card at
  that moment shows the tree instead (see "Zoomed-out card" below).

## Where the beast trees live

CommonLibSSE-NG, `RE/A/ActorValues.h`:

```
kOneHanded = 6 ... kEnchanting = 23      // the 18 skills indexed today
kWerewolfPerks = 158
kVampirePerks  = 159
```

Each is an ordinary `ActorValueInfo` (`RE/A/ActorValueInfo.h`): `fullName` from `TESFullName`
("Werewolf" / "Vampire Lord" as shown in the card), `perkTree` at 0x118 is the root
`BGSSkillPerkTreeNode`, `perkTreeWidth` at 0x120. The nodes (`RE/B/BGSSkillPerkTreeNode.h`) are the
same type as for the skills: `index` 0x08, `children` 0x10, `parents` 0x28, `perk` 0x40,
`perkGridX/Y` 0x4C/0x50, `associatedSkill` 0x58 (the owning `ActorValueInfo*`),
`horizontalPosition/verticalPosition` 0x60/0x64. Growl and Sacrosanct edit these two trees in
place, so indexing by actor value picks up their perks automatically.

`StatsMenu::RUNTIME_DATA::skillTrees` (`RE/S/StatsMenu.h`, 0x10 inside the runtime data) still
holds the 18 skills while the beast tree is shown (that is why BuildIndex reports 18), so the two
beast values have to be added explicitly. `numSelectableTrees` (0x2D0) and the `GFxValue`
commented `BeastSkillHolder` (0x2B8 area) are the engine's own beast-mode state, but nothing below
needs them.

## Proposed changes

1. **BuildIndex:** after walking `skillTrees`, also walk
   `ActorValueList::GetSingleton()->GetActorValue(ActorValue::kWerewolfPerks)->perkTree` and the
   same for `kVampirePerks`, with the same node walk and the same name key (the rank suffix is
   stripped the same way). Cheap: 11 perks each in vanilla, a few more with Growl/Sacrosanct.
   Indexing them always, not only in beast form, avoids having to detect beast form at all.

2. **Current tree:** when a centred perk is found in the index, take the tree from the node
   (`node->associatedSkill`, or the tree the node was indexed under) rather than from the last ring
   selection. In the beast menu there is no ring selection, so `AnnouncePerksBuyable` /
   `AnnouncePerksOwned` currently log "no current skill". With the tree taken from the node,
   hotkeys 3 and 4 work unchanged.

3. **Perk points:** beast perks are not bought with `PlayerCharacter` perk points. The pools are the
   globals behind `BGSDefaultObjectManager` `DEFAULT_OBJECT::kWerewolfAvailablePerks` (320) and
   `kVampireAvailablePerks` (321) (`RE/B/BGSDefaultObjectManager.h`). The "E with 0 perk points ->
   announcing refusal" check and any "N perk points" text should use the pool matching the tree:
   158 -> werewolf global, 159 -> vampire global, anything else -> the player's perk points. The
   same two names are what the menu shows in its "Perks to increase: N" field
   (`_root.StatsMenuBaseInstance.AddPerkTextInstance.AddPerkTextField.text`).

4. **Buyable test:** the skill-level part of the test (perk level against the skill's actor
   value) does not apply to these trees; perks there have level 0 and the actor value is not a
   skill. For trees 158/159, "buyable" = at least one parent owned (or root), current rank below
   the perk's rank count, perk conditions pass, and the matching pool above is greater than zero.
   Owned/rank comes from the player's perk list as for any other perk.

5. **Zoomed-out card (optional polish):** in the beast menu `_root.StatsMenuBaseInstance.bInPerkMode`
   is false while zoomed out and the description card then holds the tree, not a skill:
   `DescriptionCardInstance.CardNameTextInstance.text` ("WEREWOLF 12", the number is the level the
   game shows for the tree) and `CardDescriptionTextInstance.text` (the tree's description).
   Speaking those instead of "Skills, level N" when zoomed out, and re-announcing the centred perk
   when zooming back in, matches what sighted players see. Both `statsmenu.swf` variants
   (vanilla and the copy SkyUI ships) have this layout; there is no beast-specific Flash code.

## Expected result

With 1 and 2 alone, the beast trees get the normal announcements ("Bestial Strength, 0 of 4.
<description>"), and hotkeys 1 to 4 (children, parents, buyable, owned) work in them. 3 and 4 make
the buyable and refusal logic correct for the beast point pools. 5 fixes the misleading "Skills,
level 7" on open.

## Interim workaround

Until this lands, the "Skyrim Access Compatibility Patches" mod has an option that narrates the
beast trees from the Flash fields (tree card, centred perk with description and requirements, perk
points, confirmation box). It is a stop-gap without the parent/child/buyable/owned information the
indexed reader provides, and it will be disabled for Skyrim Access versions that include this fix.
