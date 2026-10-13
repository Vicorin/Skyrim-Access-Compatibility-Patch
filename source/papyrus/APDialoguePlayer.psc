Scriptname APDialoguePlayer extends ReferenceAlias
{Access Menu Bridge patch of the Alternate Perspective "choose your fate" start menu.
 Behaviour is identical to the original script; in addition, while the menu is open the
 focused start option, its description, its sub-option count and the final choice
 are spoken through AccessSpeech. Without AccessSpeech.dll it behaves like the original.}

String Property MENUPATH = "AlternatePerspectiveMenu" AutoReadOnly Hidden
Quest Property StartingQuest Auto Hidden

; --- Access Menu Bridge state -------------------------------------------------
String Property MENU = "CustomMenu" AutoReadOnly Hidden
String Property ROOT = "_root.main" AutoReadOnly Hidden
String Property OPT = "_root.main.menu" AutoReadOnly Hidden
String Property MAIN = "_root.main.menu.mainOptions" AutoReadOnly Hidden
String Property SUB = "_root.main.menu.subOptions" AutoReadOnly Hidden

Bool bSelPending
String sSelMod
Int iSelId
String sSelSpoken

String Function GetEventPath() global
	return "Data/SKSE/AlternatePerspective/"
EndFunction

Event OnInit()
  OnPlayerLoadGame()
EndEvent

Event OnPlayerLoadGame()
	RegisterForModEvent("AP_MessengerMenuOpen", "MenuOpen")
	RegisterForModEvent("AP_MessengerMenuSelect", "MenuSelect")
	RegisterForModEvent("AP_MessengerMenuStart", "QuestStart")
EndEvent

Event MenuOpen(string asEventName, string asStringArg, float afNumArg, form akSender)
	bSelPending = false
	sSelSpoken = ""
  UI.OpenCustomMenu(MENUPATH)
	bool j0 = SKSE.GetPluginVersion("JContainers64") == -1
	bool j1 = SKSE.GetPluginVersion("JContainersGOG") == -1
	bool j2 = SKSE.GetPluginVersion("JContainersVR") == -1
	If (j0 && j1 && j2)
		Debug.MessageBox("[Alternate Perspective]\nMissing JContainers. Only default start options will be available.")
		UI.Invoke("CustomMenu", "_root.main.openMenu")
	Else
		String[] files = JContainers.contentsOfDirectoryAtPath(GetEventPath(), ".json")
		int i = 0
		While (i < files.Length)
			If (StringUtil.Find(files[i], "AlternatePerspective.json") != -1)
				If (i != 0)
					String altPerspPath = files[i]
					files[i] = files[0]
					files[0] = altPerspPath
				EndIf
				i = files.Length
			Else
				i += 1
			EndIf
		EndWhile
		UI.InvokeStringA("CustomMenu", "_root.main.openMenu", files)
	EndIf

	; --- Access Menu Bridge: narrate the menu while it is open ---
	If AccessSpeech.IsAvailable()
		AccessLoop()
		; The menu closed. If the choice was not spoken while the menu faded out, do it now.
		If bSelPending
			bSelPending = false
			AccessSpeech.Say(DescribeChoiceFallback(), true)
		EndIf
	EndIf
EndEvent

Event MenuSelect(string asEventName, string asStringArg, float afNumArg, form akSender)
	; Access Menu Bridge: remember the choice so the narration loop can look up its name.
	sSelMod = asStringArg
	iSelId = afNumArg as Int
	bSelPending = true

	String msgErr = "[Alternate Perspective]\nInvalid Intro Quest:\n\n"
	If (afNumArg == -1)
		startingQuest = none
		Debug.Trace("[Alternate Perspective] Default (None) Quest selected")
		return
	ElseIf (Game.GetModByName(asStringArg) == 255)
		Debug.MessageBox(msgErr + "The mod " + asStringArg + " is not loaded into your game.")
		Debug.Trace("[Alternate Perspective] Quest selected from unloaded mod: " + asStringArg + "/" + afNumArg as int)
		return
	EndIf
	startingQuest = Game.GetFormFromFile(afNumArg as int, asStringArg) as Quest
	If (!startingQuest)
		Debug.MessageBox(msgErr + "The FormID " + (afNumArg as int) + " does not reference a quest in " + asStringArg + ".")
		Debug.Trace("[Alternate Perspective] Unable to find selected Quest: " + asStringArg + "/" + afNumArg as int)
	Else
		Debug.Trace("[Alternate Perspective] Quest selected: " + asStringArg + "/" + afNumArg as int + " / Name (May be empty):" + startingQuest.GetName())
	EndIf
EndEvent

; =============================================================================
; Access Menu Bridge: screen-reader support
; =============================================================================
;
; Layout of AlternatePerspectiveMenu.swf (AS2, SkyUI list components):
;   _root.main                         MessengerMenu, _options = loaded option objects
;   _root.main.menu                    OptionList
;   _root.main.menu.titlebar.title     "Choose your fate" text field
;   _root.main.menu.optiondescription  description of the focused main option
;   _root.main.menu.mainOptions        MainList (grid), entries = _entryList[i],
;                                      visible tiles = MainListEntry<clipIndex> with .name.text
;   _root.main.menu.subOptions         SubList, entries = _entryList[i],
;                                      visible rows = SubListEntry<clipIndex> with .name.text
;   <list>._selectedIndex              focused entry (-1 = none)
;   <list>.disableInput                false for the list that currently has the keys
;
; Entry objects carry text/description as "$AltPersp_..." translation keys; the visible
; tiles carry the translated text, so that is read first and the key is prettified as a
; fallback.

Function AccessLoop()
	; The JSON files load asynchronously; wait for the main list to be filled (max ~5 s).
	Int tries = 0
	Int count = UI.GetInt(MENU, MAIN + "._entryList.length")
	While count <= 0 && tries < 50 && UI.IsMenuOpen(MENU)
		Utility.WaitMenuMode(0.1)
		count = UI.GetInt(MENU, MAIN + "._entryList.length")
		tries += 1
	EndWhile
	If !UI.IsMenuOpen(MENU)
		Return
	EndIf

	String title = UI.GetString(MENU, OPT + ".titlebar.title.text")
	If title == "" || StringUtil.GetNthChar(title, 0) == "$"
		title = "Choose your fate."
	EndIf
	AccessSpeech.Say(title, true)

	Int lastMain = -2
	Int lastSub = -2
	Bool lastSubActive = false

	While UI.IsMenuOpen(MENU)
		If bSelPending
			; A choice was made; the menu is fading out for 0.6 s and can still be read.
			bSelPending = false
			AccessSpeech.Say(DescribeChoice(), true)
		Else
			Bool subActive = UI.GetBool(MENU, MAIN + ".disableInput") && !UI.GetBool(MENU, SUB + ".disableInput")
			Int mainIdx = UI.GetInt(MENU, MAIN + "._selectedIndex")
			Int subIdx = UI.GetInt(MENU, SUB + "._selectedIndex")

			If subActive != lastSubActive
				lastSubActive = subActive
				If subActive
					Int subCount = UI.GetInt(MENU, SUB + "._entryList.length")
					String line = GetEntryText(MAIN, "MainListEntry", mainIdx)
					If subCount <= 0
						String sNone = UI.GetString(MENU, SUB + ".nosuboptionstxt.text")
						If sNone == "" || StringUtil.GetNthChar(sNone, 0) == "$"
							sNone = "No additional options available."
						EndIf
						AccessSpeech.Say(line + ". " + sNone, true)
					Else
						AccessSpeech.Say(line + " sub-options.", true)
					EndIf
					lastSub = -2
				Else
					lastMain = -2
					AccessSpeech.Say("Back to the main options.", true)
				EndIf
			ElseIf subActive
				If subIdx != lastSub && subIdx >= 0
					AccessSpeech.Say(GetEntryText(SUB, "SubListEntry", subIdx) + ".", true)
					lastSub = subIdx
				EndIf
			Else
				If mainIdx != lastMain && mainIdx >= 0
					AccessSpeech.Say(DescribeMainOption(mainIdx), true)
					lastMain = mainIdx
				EndIf
			EndIf
		EndIf
		Utility.WaitMenuMode(0.1)
	EndWhile
EndFunction

String Function DescribeMainOption(Int aiIndex)
	String line = GetEntryText(MAIN, "MainListEntry", aiIndex)
	If !UI.GetBool(MENU, MAIN + "._entryList." + aiIndex + ".enabled")
		line += ", unavailable"
	EndIf
	String desc = UI.GetString(MENU, OPT + ".optiondescription.text")
	If desc == "" || StringUtil.GetNthChar(desc, 0) == "$"
		desc = Prettify(UI.GetString(MENU, MAIN + "._entryList." + aiIndex + ".description"))
	EndIf
	If desc != ""
		line += ". " + desc
	EndIf
	Int subCount = UI.GetInt(MENU, MAIN + "._entryList." + aiIndex + ".suboptions.length")
	If subCount > 0
		line += " " + subCount + " sub-options."
	EndIf
	String modName = UI.GetString(MENU, MAIN + "._entryList." + aiIndex + ".mod")
	If modName != "" && modName != "N/A" && modName != "AlternatePerspective.esp"
		line += " From " + modName + "."
	EndIf
	Return line
EndFunction

; Translated text of entry aiIndex of a list, read from its visible tile; falls back to the
; prettified translation key stored in the entry object.
String Function GetEntryText(String asList, String asClipPrefix, Int aiIndex)
	If aiIndex < 0
		Return ""
	EndIf
	String t = ""
	Int clip = UI.GetInt(MENU, asList + "._entryList." + aiIndex + ".clipIndex")
	If clip >= 0 && UI.GetInt(MENU, asList + "." + asClipPrefix + clip + ".itemIndex") == aiIndex
		t = UI.GetString(MENU, asList + "." + asClipPrefix + clip + ".name.text")
	EndIf
	If t == "" || StringUtil.GetNthChar(t, 0) == "$"
		t = Prettify(UI.GetString(MENU, asList + "._entryList." + aiIndex + ".text"))
	EndIf
	Return t
EndFunction

; "$AltPersp_TheBanneredMare" -> "The Bannered Mare". Plain text is returned unchanged.
String Function Prettify(String asKey)
	If asKey == "" || StringUtil.GetNthChar(asKey, 0) != "$"
		Return asKey
	EndIf
	String s = StringUtil.Substring(asKey, 1)
	Int us = StringUtil.Find(s, "_")
	If us >= 0
		s = StringUtil.Substring(s, us + 1)
	EndIf
	String out = ""
	Int n = StringUtil.GetLength(s)
	Int i = 0
	Int prev = 0
	While i < n
		String c = StringUtil.GetNthChar(s, i)
		Int o = StringUtil.AsOrd(c)
		Bool upper = o >= 65 && o <= 90
		Bool digit = o >= 48 && o <= 57
		Bool prevLower = prev >= 97 && prev <= 122
		Bool prevDigit = prev >= 48 && prev <= 57
		If i > 0 && ((upper && (prevLower || prevDigit)) || (digit && prevLower))
			out += " "
		EndIf
		out += c
		prev = o
		i += 1
	EndWhile
	Return out
EndFunction

; Spoken summary of the choice that just closed the menu, looked up in the SWF's option
; data (_root.main._options) while the menu is still fading out.
String Function DescribeChoice()
	If iSelId == -1
		Return "Default start chosen: you begin in the Resting Pilgrim, Helgen's inn."
	EndIf
	Int count = UI.GetInt(MENU, ROOT + "._options.length")
	Int i = 0
	While i < count
		String p = ROOT + "._options." + i
		If UI.GetString(MENU, p + ".mod") == sSelMod
			Int subCount = UI.GetInt(MENU, p + ".suboptions.length")
			If subCount > 0
				Int j = 0
				While j < subCount
					If UI.GetInt(MENU, p + ".suboptions." + j + ".id") == iSelId
						Return "Chosen: " + Prettify(UI.GetString(MENU, p + ".text")) + ", " + Prettify(UI.GetString(MENU, p + ".suboptions." + j + ".text")) + "."
					EndIf
					j += 1
				EndWhile
			ElseIf UI.GetInt(MENU, p + ".id") == iSelId
				Return "Chosen: " + Prettify(UI.GetString(MENU, p + ".text")) + "."
			EndIf
		EndIf
		i += 1
	EndWhile
	Return DescribeChoiceFallback()
EndFunction

String Function DescribeChoiceFallback()
	If iSelId == -1
		Return "Default start chosen: you begin in the Resting Pilgrim, Helgen's inn."
	EndIf
	If StartingQuest && StartingQuest.GetName() != ""
		Return "Chosen: " + StartingQuest.GetName() + "."
	EndIf
	Return "Start option chosen."
EndFunction
