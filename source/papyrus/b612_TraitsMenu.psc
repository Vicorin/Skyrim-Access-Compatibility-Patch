Scriptname b612_TraitsMenu extends b612_Base
{Access Menu Bridge patch of B612's traits menu (used by Biggie Traits).
 Behaviour is identical to the original; in addition, while the menu is open the
 focused trait, its description, its selected state and the Confirm/Random buttons are
 spoken through AccessSpeech (Skyrim Access style screen-reader output).
 If AccessSpeech.dll is missing the menu behaves exactly like the original.}

String sSelectedIndexes
Int iMinSelection
Int iMaxSelection
String sChosenTitles

String Property MENU = "CustomMenu" AutoReadOnly
String Property MC = "_root.Traits_mc" AutoReadOnly
String Property ITEMS = "_root.Traits_mc.ItemsContainerWrap_mc.ItemsContainer_mc.item_" AutoReadOnly

Bool Function Init()
    UI.OpenCustomMenu("b612_traitsmenut")
    While ! UI.GetBool(MENU, "_root.isLoaded")
        Utility.WaitMenuMode(0.1)
    EndWhile
    Return True
EndFunction

Function AddItem(String astitle, String asDescription, String asImagePath)
    String[] args = new String[3]
    args[0] = astitle
    args[1] = asDescription
    args[2] = asImagePath
    UI.InvokeStringA(MENU, MC + ".addItem", args)
EndFunction

String[] Function Show(Int aiMaxSelection = 1, Int aiMinSelection = 0)
    RegisterForModEvent("b612_TraitsMenu_Close", "Onb612_TraitsMenu_Close")
    UI.InvokeInt(MENU, MC + ".setMaxSelection", aiMaxSelection)
    UI.InvokeInt(MENU, MC + ".setMinSelection", aiMinSelection)
    iMinSelection = aiMinSelection
    iMaxSelection = aiMaxSelection
    sChosenTitles = ""
    UI.Invoke(MENU, MC + ".render")

    If AccessSpeech.IsAvailable()
        AccessLoop()
    Else
        LockWait(MENU)
    EndIf

    If sChosenTitles != ""
        AccessSpeech.Say("Confirmed: " + sChosenTitles, true)
    EndIf

    String[] SelectedIndexes = StringUtil.Split(sSelectedIndexes, ",")
    Return SelectedIndexes
EndFunction

Event Onb612_TraitsMenu_Close(string eventName, string strArg, float numArg, Form formArg)
    sSelectedIndexes = strArg
    ; Read the chosen titles while the menu still exists so they can be spoken after it closes.
    If strArg != "" && AccessSpeech.IsAvailable()
        String[] idx = StringUtil.Split(strArg, ",")
        Int i = 0
        While i < idx.Length
            String t = GetTitle(idx[i] as Int)
            If t != ""
                If sChosenTitles != ""
                    sChosenTitles += ", "
                EndIf
                sChosenTitles += t
            EndIf
            i += 1
        EndWhile
    EndIf
    UI.CloseCustomMenu()
    UnregisterForModEvent("b612_TraitsMenu_Close")
EndEvent

; ---------------------------------------------------------------------------
; Screen-reader support
; ---------------------------------------------------------------------------

String Function GetTitle(Int aiIndex)
    If aiIndex < 0
        Return ""
    EndIf
    ; The rendered text field holds the translated name; the data entry is the fallback.
    String t = UI.GetString(MENU, ITEMS + aiIndex + ".ItemName_tf.text")
    If t == ""
        t = UI.GetString(MENU, MC + ".data." + aiIndex + ".title")
    EndIf
    Return t
EndFunction

String Function GetDescription(Int aiIndex)
    ; ItemText_tf shows the description of the focused item (plain text, tags stripped).
    String d = UI.GetString(MENU, MC + ".ItemText_tf.text")
    If d == ""
        d = UI.GetString(MENU, MC + ".data." + aiIndex + ".description")
    EndIf
    Return d
EndFunction

Bool Function IsSelected(Int aiIndex)
    Return UI.GetBool(MENU, ITEMS + aiIndex + ".EquipIcon_mc._visible")
EndFunction

String Function GetCounter()
    Return UI.GetString(MENU, MC + ".StatusText_tf.text")
EndFunction

Function AccessLoop()
    Int count = UI.GetInt(MENU, MC + ".data.length")

    String intro = "Trait selection. " + count + " traits. "
    If iMinSelection >= iMaxSelection
        If iMaxSelection == 1
            intro += "Choose 1 trait. "
        Else
            intro += "Choose " + iMaxSelection + " traits. "
        EndIf
    ElseIf iMinSelection <= 0
        intro += "Choose up to " + iMaxSelection + ". "
    Else
        intro += "Choose " + iMinSelection + " to " + iMaxSelection + ". "
    EndIf
    intro += "Down arrow to start browsing, up and down to move, Enter to select or deselect, right arrow for the Random and Confirm buttons, Enter on Confirm to finish."
    AccessSpeech.Say(intro, true)

    Int lastFocus = -2
    String lastButton = ""
    Int lastSelCount = UI.GetInt(MENU, MC + ".selections.length")

    While UI.IsMenuOpen(MENU)
        Int focus = UI.GetInt(MENU, MC + ".iFocusIndex")
        String button = UI.GetString(MENU, MC + ".currentFocus._name")
        Int selCount = UI.GetInt(MENU, MC + ".selections.length")

        If button != ""
            If button != lastButton
                If button == "OkBtn_mc"
                    AccessSpeech.Say("Confirm button. " + GetCounter(), true)
                ElseIf button == "RandomBtn_mc"
                    AccessSpeech.Say("Random button. Picks traits at random and confirms.", true)
                Else
                    AccessSpeech.Say(button, true)
                EndIf
                lastButton = button
                lastFocus = -2
            EndIf
        ElseIf focus != lastFocus && focus >= 0
            String line = GetTitle(focus)
            If IsSelected(focus)
                line += ", selected"
            EndIf
            line += ". " + GetDescription(focus)
            AccessSpeech.Say(line, true)
            lastFocus = focus
            lastButton = ""
            lastSelCount = selCount
        ElseIf selCount != lastSelCount && focus >= 0
            String verb = "Deselected "
            If IsSelected(focus)
                verb = "Selected "
            EndIf
            AccessSpeech.Say(verb + GetTitle(focus) + ". " + GetCounter(), true)
            lastSelCount = selCount
        EndIf

        Utility.WaitMenuMode(0.1)
    EndWhile
EndFunction
