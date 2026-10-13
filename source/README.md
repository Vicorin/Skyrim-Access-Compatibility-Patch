# Skyrim Access Compatibility Patches

Screen-reader support for the custom menus and message boxes of other mods, built to work
alongside **Skyrim Access** (which does not read custom SWF menus and, with some message box
replacers, not message boxes either). Currently covered:

* **Alternate Perspective** "choose your fate" start menu
* **Biggie Traits** trait selection (the B612 traits menu)
* **Why I Came to Skyrim - Origin Stories** backstory selection
* **Lawbringer** banner claiming (its message boxes)

While one of these menus is open, the focused entry and its description are spoken, along with
whatever else that menu needs (selected state, sub-options, buttons, the final choice). The menus
themselves are unchanged; only the Papyrus scripts that drive them are replaced.

## Installing

The archive is a FOMOD. In Vortex or Mod Organizer the installer shows one option per supported
mod and pre-selects the ones it detects in your load order (by their plugin file). Install it
**after** the mods it patches so its scripts win the file conflicts: in Vortex, choose
"Skyrim Access Compatibility Patches" as the winner (load after) for each conflict it reports.

The AccessSpeech plugin is always installed; the per-mod scripts only when selected. Patches for
mods you do not have are harmless but pointless.

## What is in the mod

| Installer option | Files | Purpose |
| --- | --- | --- |
| always | `SKSE/Plugins/AccessSpeech.dll`, `AccessSpeech.ini`, `Scripts/AccessSpeech.pex` | SKSE plugin adding a Papyrus script `AccessSpeech` with `Say`, `Stop`, `IsAvailable`, `GetBackendName`, `GetVersion`. Speech goes to **NVDA** (via `nvdaControllerClient.dll` in the game folder) when NVDA is running, otherwise to **Windows SAPI 5**. `Backend=auto|nvda|sapi` in the ini. Any mod can call `AccessSpeech.Say("text")`. |
| Alternate Perspective | `Scripts/APDialoguePlayer.pex` | Patched start-menu script. |
| Biggie Traits | `Scripts/b612_TraitsMenu.pex` | Patched B612 traits menu script. |
| Why I Came to Skyrim | `Scripts/JayUI_Script.pex` | Patched backstory menu script. |
| Lawbringer | `Scripts/LCO_SimpleControllerBase.pex`, `Scripts/LCO_ShorsWatchtowerController.pex`, `Scripts/LCO_Access.pex` | Patched banner scripts plus a helper that narrates the message boxes. |

Sources of all scripts are included under `Source/Scripts`.

## Requirements

* Skyrim SE **1.7.104** with **SKSE 2.3.1** (the DLL is built from the SKSE 2.3.1 sources
  for this exact runtime; rebuild it after a game update).
* NVDA running, or any SAPI 5 voice installed (Windows ships with several).
* Alternate Perspective needs a JContainers build that loads on your SKSE version, or its
  menu only offers "None" and "Random" (that is the mod's own limitation, not this patch).

## What is spoken

**Alternate Perspective:** when you activate the Shrine of Akatosh, the menu announces "Choose your
fate." Each tile is spoken as its name, then its description, then how many sub-options it has
("Regular (Inn). You're a Regular at an Inn somewhere in Skyrim or Solstheim. 18 sub-options.").
Enter on a tile with sub-options opens the second list ("Regular (Inn) sub-options."), where each
row is spoken by name. Enter on a tile without sub-options starts it directly. "Random" draws a
start for you; the result is spoken as the menu closes ("Chosen: Vampire, Movarth's Lair."). Escape
on the main list closes the menu with the default start in Helgen's inn, and says so. Options added
by other mods are read the same way and name the mod they come from.

**Biggie Traits:** Down arrow to start browsing, up/down to move, Enter to select or
deselect, right arrow to reach the Random and Confirm buttons, Enter on Confirm to finish.
The intro also states how many traits must be chosen.

**Why I Came to Skyrim:** a grid of three columns. Arrow keys move, Enter selects, right
arrow past the last column reaches the Random and Confirm buttons, Enter on Confirm starts
the chosen story. Random picks a story at random and confirms immediately.

**Lawbringer:** activating a banner post speaks the location and who holds it, then the message
box text and its visible buttons, the highlighted button as you move, and the result afterwards
("Banner raised for The Empire. Pinefall Bridge changes hands in 5 minutes, after 24 hours in
game, or when you leave the area."). Only the buttons the mod actually shows are listed.

## Troubleshooting

* Log: `Documents\My Games\Skyrim Special Edition\SKSE\AccessSpeech.log`
  shows which backend was found ("nvda=1 (running=1) sapi=1").
* If nothing is spoken but the menu works normally, the DLL did not load
  (check `skse64.log` for `AccessSpeech.dll`), or the patched script is not the one deployed
  (check the file conflict rules in your mod manager).
* If the menu does not react to keys at all, that is unrelated to this mod (the SWF
  handles input itself).

## Building

```
powershell -ExecutionPolicy Bypass -File build.ps1
```

Needs Visual Studio 2022 Build Tools, CMake, the SKSE 2.3.1 sources extracted to
`C:\Users\Josh\SkyrimDev\skse64-2.3.1\skse64-2.3.1` and ianpatt's `common` library at
`<game>\src\common` (both paths are CMake cache variables). The Papyrus scripts are compiled
with the game's own `Papyrus Compiler`. Output: `dist\Skyrim Access Compatibility Patches.zip`
(FOMOD layout: `fomod\`, `Core\`, `Patches\<option>\`). Add a new patch by dropping its `.psc`
into `papyrus\`, mapping it to an option folder in `$Patches` in `build.ps1`, and adding a
`<plugin>` to `fomod\ModuleConfig.xml`.

`build\Release\SpeechTest.exe "hello"` speaks a sentence outside the game to check the
NVDA / SAPI backends.
