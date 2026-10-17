Scriptname SACP_BeastPerkTree extends ReferenceAlias
{Skyrim Access Compatibility Patches: speaks the Werewolf / Vampire Lord perk tree.

 Skyrim Access reads the normal skills menu, but the beast perk tree (the skills menu while
 transformed) stays silent: it skips the skill ring and uses the Werewolf / Vampire perk
 actor values, which the perk index of Skyrim Access does not cover. This script, on the
 player alias of a start-game-enabled quest, watches the StatsMenu. When it opens as a beast
 tree it speaks the tree name, the perk points, the centred perk with its description and
 requirements, perk point changes and the purchase confirmation box, through AccessSpeech.
 In the normal skills menu it does nothing.

 Layout of statsmenu.swf (vanilla and the SkyUI copy are the same here):
   _root.StatsMenuBaseInstance                    frame 1 "Skills" (ring), 2 "Perks" (tree)
   .bInPerkMode                                   true in the tree view
   .PerkName<i>                                   one label per perk visible in the tree;
                                                  frame 1 "Invisible" = unused; scale grows
                                                  with the position down the screen, so the
                                                  selected (nearest) perk has the largest label
   .PerkName<i>.PerkNameClipInstance.NameText     perk name
   .DescriptionCardInstance.Perktype              tree name ("Werewolf", a skill name, ...)
   .DescriptionCardInstance.CardDescriptionTextInstance   perk description
   .DescriptionCardInstance.SkillRequirementText  TREE NAME + spaces + REQUIREMENTS
   .AddPerkTextInstance.AddPerkTextField          "Perks to increase: N" (alpha 0 when none)}

String Property MENU = "StatsMenu" AutoReadOnly Hidden
String Property MSG = "MessageBoxMenu" AutoReadOnly Hidden
String Property BASE = "_root.StatsMenuBaseInstance" AutoReadOnly Hidden
String Property CARD = "_root.StatsMenuBaseInstance.DescriptionCardInstance" AutoReadOnly Hidden
String Property BTN = "_root.MessageMenu.Buttons.Button" AutoReadOnly Hidden

; Hotkeys while the tree is open, same as Skyrim Access in the normal trees:
; 1 what the perk leads to, 2 its prerequisites, 3 perks you can learn now, 4 perks you own.
Int Property KEY_1 = 2 AutoReadOnly Hidden
Int Property KEY_2 = 3 AutoReadOnly Hidden
Int Property KEY_3 = 4 AutoReadOnly Hidden
Int Property KEY_4 = 5 AutoReadOnly Hidden

Bool bNarrating
String sCurPerk
Int iCurTree

Event OnInit()
	OnPlayerLoadGame()
EndEvent

Event OnPlayerLoadGame()
	RegisterForMenu(MENU)
EndEvent

Event OnMenuOpen(String asMenu)
	If asMenu != MENU || !AccessSpeech.IsAvailable()
		Return
	EndIf
	If IsBeastTree()
		Narrate()
	EndIf
EndEvent

; True when the skills menu that just opened is a beast perk tree.
Bool Function IsBeastTree()
	If IsBeastRace(Game.GetPlayer().GetRace())
		Return True
	EndIf
	; Other beast races (from mods) give themselves away: the menu opens straight in the
	; tree view, on a tree that is not one of the eighteen skills. A player cannot zoom into
	; a normal tree within the first half second.
	Int tries = 0
	While tries < 5 && UI.IsMenuOpen(MENU)
		Utility.WaitMenuMode(0.1)
		If UI.GetInt(MENU, BASE + "._currentframe") == 2
			String tree = UI.GetString(MENU, CARD + ".Perktype.text")
			Return tree != "" && !IsStandardSkill(tree)
		EndIf
		tries += 1
	EndWhile
	Return False
EndFunction

Bool Function IsBeastRace(Race akRace)
	If !akRace
		Return False
	EndIf
	If akRace == Game.GetForm(0x000CDD84) as Race ; WerewolfBeastRace
		Return True
	EndIf
	If akRace == Game.GetFormFromFile(0x0000283A, "Dawnguard.esm") as Race ; DLC1VampireBeastRace
		Return True
	EndIf
	If akRace == Game.GetFormFromFile(0x0001E17B, "Dragonborn.esm") as Race ; DLC2WerebearBeastRace
		Return True
	EndIf
	Return False
EndFunction

Bool Function IsStandardSkill(String asName)
	; Papyrus string comparison ignores case.
	If asName == "One-Handed" || asName == "Two-Handed" || asName == "Archery" || asName == "Marksman"
		Return True
	EndIf
	If asName == "Block" || asName == "Smithing" || asName == "Heavy Armor" || asName == "Light Armor"
		Return True
	EndIf
	If asName == "Pickpocket" || asName == "Lockpicking" || asName == "Sneak" || asName == "Alchemy"
		Return True
	EndIf
	If asName == "Speech" || asName == "Speechcraft" || asName == "Alteration" || asName == "Conjuration"
		Return True
	EndIf
	If asName == "Destruction" || asName == "Illusion" || asName == "Restoration" || asName == "Enchanting"
		Return True
	EndIf
	Return False
EndFunction

; =============================================================================

Function Narrate()
	; The card is filled by the game a moment after the menu opens.
	String tree = UI.GetString(MENU, CARD + ".Perktype.text")
	Int tries = 0
	While tree == "" && tries < 20 && UI.IsMenuOpen(MENU)
		Utility.WaitMenuMode(0.1)
		tree = UI.GetString(MENU, CARD + ".Perktype.text")
		tries += 1
	EndWhile
	If !UI.IsMenuOpen(MENU)
		Return
	EndIf

	sCurPerk = ""
	iCurTree = 0
	bNarrating = true
	RegisterForKey(KEY_1)
	RegisterForKey(KEY_2)
	RegisterForKey(KEY_3)
	RegisterForKey(KEY_4)

	String intro = "Perk tree."
	If tree != ""
		intro = tree + " perks."
	EndIf
	String points = PerkPointsText()
	If points != ""
		intro += " " + points + "."
	EndIf
	AccessSpeech.Say(intro, true)

	; The tree has two views: zoomed out (the card shows the tree name, its level and its
	; description) and zoomed in (the card shows the selected perk). bInPerkMode tells which.
	Bool perkMode = UI.GetBool(MENU, BASE + ".bInPerkMode")
	If !perkMode
		AccessSpeech.Say(DescribeTree(), false)
	EndIf

	String lastPerk = ""
	String candidate = ""
	String lastPoints = points
	Bool first = true
	While UI.IsMenuOpen(MENU)
		If UI.IsMenuOpen(MSG)
			; Perk purchase confirmation.
			NarrateMessageBox()
		Else
			Bool nowPerkMode = UI.GetBool(MENU, BASE + ".bInPerkMode")
			If nowPerkMode != perkMode
				perkMode = nowPerkMode
				If perkMode
					; Zoomed in: read the focused perk even if it is the one read before zooming out.
					lastPerk = ""
					candidate = ""
				Else
					AccessSpeech.Say(DescribeTree(), true)
				EndIf
			ElseIf perkMode
				; A perk counts once its label has been the largest for two polls in a row, so the
				; camera flight between perks is not read out.
				String name = CenteredPerk()
				If name != "" && name == candidate && name != lastPerk
					lastPerk = name
					AccessSpeech.Say(DescribePerk(name), !first)
					first = false
				EndIf
				candidate = name
			EndIf

			points = PerkPointsText()
			If points != lastPoints
				lastPoints = points
				If points != ""
					AccessSpeech.Say(points + ".", false)
				EndIf
			EndIf
		EndIf
		Utility.WaitMenuMode(0.1)
	EndWhile

	bNarrating = false
	UnregisterForKey(KEY_1)
	UnregisterForKey(KEY_2)
	UnregisterForKey(KEY_3)
	UnregisterForKey(KEY_4)
EndFunction

Event OnKeyDown(Int aiKey)
	If !bNarrating || !UI.IsMenuOpen(MENU) || UI.IsMenuOpen(MSG)
		Return
	EndIf
	If aiKey == KEY_1 || aiKey == KEY_2
		If sCurPerk == ""
			AccessSpeech.Say("No perk selected.", true)
			Return
		EndIf
		String[] info = AccessSpeech.DescribeBeastPerk(sCurPerk)
		If info.Length < 13 || info[0] != "1"
			AccessSpeech.Say("No details for " + sCurPerk + ".", true)
		ElseIf aiKey == KEY_1
			If info[8] == ""
				AccessSpeech.Say("This perk leads nowhere further.", true)
			Else
				AccessSpeech.Say("Leads to " + info[8] + ".", true)
			EndIf
		Else
			If info[7] == ""
				AccessSpeech.Say("Root perk, no prerequisite.", true)
			Else
				AccessSpeech.Say("Requires " + info[7] + ".", true)
			EndIf
		EndIf
	ElseIf aiKey == KEY_3
		String[] canBuy = AccessSpeech.ListBeastPerks(iCurTree, 0, MenuPerkPoints())
		If canBuy.Length == 0
			AccessSpeech.Say("No perks can be learned now in this tree.", true)
		Else
			AccessSpeech.Say("Can be learned now: " + JoinList(canBuy) + ".", true)
		EndIf
	ElseIf aiKey == KEY_4
		String[] owned = AccessSpeech.ListBeastPerks(iCurTree, 1)
		If owned.Length == 0
			AccessSpeech.Say("You have no perks in this tree.", true)
		Else
			AccessSpeech.Say("Owned: " + JoinList(owned) + ".", true)
		EndIf
	EndIf
EndEvent

String Function JoinList(String[] asItems)
	String s = ""
	Int i = 0
	While i < asItems.Length
		If i > 0
			s += "; "
		EndIf
		s += asItems[i]
		i += 1
	EndWhile
	Return s
EndFunction

; Zoomed-out view: the card names the tree with its level ("WEREWOLF 12") and describes it.
String Function DescribeTree()
	String s = SentenceCase(Trim(UI.GetString(MENU, CARD + ".CardNameTextInstance.text")))
	If s == ""
		s = "Perk tree"
	EndIf
	s += "."
	String desc = Trim(UI.GetString(MENU, CARD + ".CardDescriptionTextInstance.text"))
	If desc != ""
		s += " " + desc
		If !EndsWithPunctuation(desc)
			s += "."
		EndIf
	EndIf
	Return s
EndFunction

; Name on the largest visible perk label, which is the selected perk ("" if none).
String Function CenteredPerk()
	String best = ""
	Float bestScale = 0.0
	Int i = 0
	Bool more = true
	While more && i < 64
		String clip = BASE + ".PerkName" + i
		; Labels are used from 0 upwards; the first one on its "Invisible" frame (1) or not
		; attached at all (0) ends the list.
		If UI.GetInt(MENU, clip + "._currentframe") <= 1
			more = false
		Else
			Float scale = UI.GetFloat(MENU, clip + "._xscale")
			If scale > bestScale
				String n = UI.GetString(MENU, clip + ".PerkNameClipInstance.NameText.text")
				If n != ""
					best = n
					bestScale = scale
				EndIf
			EndIf
			i += 1
		EndIf
	EndWhile
	Return best
EndFunction

String Function DescribePerk(String asName)
	sCurPerk = asName
	If AccessSpeech.GetVersion() >= 2
		String[] info = AccessSpeech.DescribeBeastPerk(asName)
		If info.Length >= 13 && info[0] == "1"
			iCurTree = info[11] as Int
			String s = info[1]
			Int owned = info[3] as Int
			Int total = info[4] as Int
			If total > 1
				s += ", " + owned + " of " + total
			EndIf
			s += "."
			; The menu's card describes the rank you would buy next; the perk record is the fallback.
			String desc = Trim(UI.GetString(MENU, CARD + ".CardDescriptionTextInstance.text"))
			If desc == ""
				desc = info[2]
			EndIf
			If desc != ""
				s += " " + desc
				If !EndsWithPunctuation(desc)
					s += "."
				EndIf
			EndIf
			; Perk points as the menu counts them ("Perks to increase: 2").
			Int points = MenuPerkPoints()
			If points < 0
				points = info[10] as Int
			EndIf
			If owned >= total
				s += " Fully learned."
			ElseIf info[12] != "1"
				s += " Needs " + info[7] + " first."
			ElseIf points <= 0
				s += " No perk points available."
			Else
				s += " Can be learned now."
			EndIf
			If info[7] != ""
				s += " Requires " + info[7] + "."
			EndIf
			If info[8] != ""
				s += " Leads to " + info[8] + "."
			EndIf
			Return s
		EndIf
	EndIf
	; Fallback: what the menu's own description card shows.
	String s = asName + "."
	String desc = UI.GetString(MENU, CARD + ".CardDescriptionTextInstance.text")
	If desc != ""
		s += " " + desc
		If !EndsWithPunctuation(desc)
			s += "."
		EndIf
	EndIf
	String req = Requirements()
	If req != ""
		s += " " + req
		If !EndsWithPunctuation(req)
			s += "."
		EndIf
	EndIf
	Return s
EndFunction

; The requirements line is "TREE NAME" + ten spaces + "REQUIRES: ..." in capitals; return the
; second part in sentence case.
String Function Requirements()
	String t = UI.GetString(MENU, CARD + ".SkillRequirementText.text")
	Int gap = StringUtil.Find(t, "   ")
	If gap < 0
		Return ""
	EndIf
	Return SentenceCase(Trim(StringUtil.Substring(t, gap)))
EndFunction

String Function PerkPointsText()
	If UI.GetFloat(MENU, BASE + ".AddPerkTextInstance._alpha") <= 0.0
		Return ""
	EndIf
	Return Trim(UI.GetString(MENU, BASE + ".AddPerkTextInstance.AddPerkTextField.text"))
EndFunction

; Number in the menu's perk counter; 0 when the counter is hidden (no points); -1 if unreadable.
Int Function MenuPerkPoints()
	String t = PerkPointsText()
	If t == ""
		Return 0
	EndIf
	Int value = -1
	Int n = StringUtil.GetLength(t)
	Int i = 0
	While i < n
		Int o = StringUtil.AsOrd(StringUtil.GetNthChar(t, i))
		If o >= 48 && o <= 57
			If value < 0
				value = 0
			EndIf
			value = value * 10 + (o - 48)
		ElseIf value >= 0
			i = n
		EndIf
		i += 1
	EndWhile
	Return value
EndFunction

; ---------------------------------------------------------------------------
; Message box (perk purchase confirmation) on top of the tree

Function NarrateMessageBox()
	Utility.WaitMenuMode(0.15)
	If !UI.IsMenuOpen(MSG)
		Return
	EndIf
	String text = UI.GetString(MSG, "_root.MessageMenu.MessageText.text")

	; Hidden buttons leave gaps in Button0..Button7, so collect the visible ones.
	String[] labels = Utility.CreateStringArray(8)
	Int n = 0
	Int i = 0
	While i < 8
		String l = UI.GetString(MSG, BTN + i + ".ButtonText.text")
		If l != "" && l != " "
			labels[n] = l
			n += 1
		EndIf
		i += 1
	EndWhile
	String options = ""
	i = 0
	While i < n
		If i > 0
			options += ", "
		EndIf
		options += labels[i]
		i += 1
	EndWhile
	AccessSpeech.Say(Trim(text) + " " + options, true)

	Int last = FocusedButton(n)
	While UI.IsMenuOpen(MSG) && UI.IsMenuOpen(MENU)
		Int f = FocusedButton(n)
		If f >= 0 && f < n && f != last
			If last >= 0
				AccessSpeech.Say(labels[f], true)
			EndIf
			last = f
		EndIf
		Utility.WaitMenuMode(0.1)
	EndWhile
EndFunction

Int Function FocusedButton(Int n)
	; Better MessageBox Controls / SkyUI message box: lastTabIndex tracks the focused button.
	Int idx = UI.GetInt(MSG, "_root.MessageMenu.lastTabIndex")
	If idx >= 0 && idx < n
		Return idx
	EndIf
	Int dense = 0
	Int i = 0
	While i < 8
		String l = UI.GetString(MSG, BTN + i + ".ButtonText.text")
		If l != "" && l != " "
			If UI.GetInt(MSG, BTN + i + ".focused") != 0
				Return dense
			EndIf
			dense += 1
		EndIf
		i += 1
	EndWhile
	Return -1
EndFunction

; ---------------------------------------------------------------------------
; String helpers

String Function Trim(String s)
	While StringUtil.GetLength(s) > 0 && IsSpace(StringUtil.GetNthChar(s, 0))
		s = StringUtil.Substring(s, 1)
	EndWhile
	Int n = StringUtil.GetLength(s)
	While n > 0 && IsSpace(StringUtil.GetNthChar(s, n - 1))
		s = StringUtil.Substring(s, 0, n - 1)
		n -= 1
	EndWhile
	Return s
EndFunction

Bool Function IsSpace(String c)
	Int o = StringUtil.AsOrd(c)
	Return o == 32 || o == 9 || o == 10 || o == 13
EndFunction

Bool Function EndsWithPunctuation(String s)
	Int n = StringUtil.GetLength(s)
	If n == 0
		Return True
	EndIf
	String c = StringUtil.GetNthChar(s, n - 1)
	Return c == "." || c == "!" || c == "?" || c == ":"
EndFunction

; "REQUIRES: BESTIAL STRENGTH" -> "Requires: bestial strength"
String Function SentenceCase(String s)
	Int n = StringUtil.GetLength(s)
	If n == 0
		Return s
	EndIf
	String out = StringUtil.GetNthChar(s, 0)
	Int i = 1
	While i < n
		String c = StringUtil.GetNthChar(s, i)
		Int o = StringUtil.AsOrd(c)
		If o >= 65 && o <= 90
			c = StringUtil.AsChar(o + 32)
		EndIf
		out += c
		i += 1
	EndWhile
	Return out
EndFunction
