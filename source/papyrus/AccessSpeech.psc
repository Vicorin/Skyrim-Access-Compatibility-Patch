Scriptname AccessSpeech Hidden
{Screen-reader speech bridge for Papyrus. Implemented by AccessSpeech.dll (SKSE plugin).
 Speech goes to NVDA when it is running, otherwise to Windows SAPI 5.
 All functions return immediately; speech is queued on a background thread.}

; Speak text. If abInterrupt is true, anything currently being spoken is cut off first.
Function Say(String asText, Bool abInterrupt = true) Global Native

; Stop all speech immediately.
Function Stop() Global Native

; True when the plugin is loaded and at least one speech backend works.
Bool Function IsAvailable() Global Native

; "NVDA", "SAPI" or "none".
String Function GetBackendName() Global Native

; Plugin version number (1 = first release, 2 = beast perk tree functions).
Int Function GetVersion() Global Native

; --- Werewolf / Vampire Lord perk trees (plugin version 2) --------------------------------------
; Looks a perk up by the label shown in the beast skill tree ("Bestial Strength (1/4)" or just the
; name). Returns 13 strings:
;   0 "1" if found, "0" if not        1 perk name                2 description (of the next rank)
;   3 owned ranks                     4 total ranks              5 "1" if it can be bought now
;   6 why it cannot be bought ("")    7 prerequisites            8 perks it leads to
;   9 tree name                      10 perk points available   11 tree actor value (158 werewolf, 159 vampire)
;  12 "1" if its prerequisites are met (a connected parent perk owned, or it is a root perk)
String[] Function DescribeBeastPerk(String asLabel) Global Native

; Perk names of a beast tree (aiTree 158, 159, or 0 for both). aiMode: 0 = can be bought now,
; 1 = owned, 2 = all. Multi-rank perks read "Name, rank x of y". aiPoints: the perk points to assume
; for mode 0 (what the menu shows), or -1 to read the game's pool.
String[] Function ListBeastPerks(Int aiTree, Int aiMode, Int aiPoints = -1) Global Native
