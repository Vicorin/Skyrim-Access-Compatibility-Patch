Scriptname JayUI_Script extends Quest
{Access Menu Bridge patch of the "Why I Came to Skyrim" backstory menu.
 Behaviour is identical to the original; in addition, while the menu is open the
 focused story title, its description, its selected state and the Confirm/Random buttons
 are spoken through AccessSpeech. Without AccessSpeech.dll it behaves like the original.}

Int choice
String sChosenTitle

String Property MENU = "CustomMenu" AutoReadOnly
String Property MC = "_root.Traits_mc" AutoReadOnly
String Property ITEMS = "_root.Traits_mc.ItemsContainerWrap_mc.ItemsContainer_mc.item_" AutoReadOnly

Int Function OpenMenu()
    choice = -1
    sChosenTitle = ""
    RegisterForModEvent("JayMenu_Close", "OnCloseMenu")
    UI.OpenCustomMenu("jay_menu")

    If AccessSpeech.IsAvailable()
        AccessLoop()
    Else
        While UI.IsMenuOpen(MENU)
            Utility.Wait(0.1)
        EndWhile
    EndIf

    UnregisterForModEvent("JayMenu_Close")

    If sChosenTitle != ""
        AccessSpeech.Say("Chosen: " + sChosenTitle, true)
    ElseIf choice < 0 && AccessSpeech.IsAvailable()
        AccessSpeech.Say("No backstory chosen.", true)
    EndIf
    Return choice
EndFunction

Event OnCloseMenu(string eventName, string strArg, float numArg, Form formArg)
    choice = strArg as Int
    If choice >= 0 && AccessSpeech.IsAvailable()
        sChosenTitle = GetTitle(choice)
    EndIf
    UI.CloseCustomMenu()
EndEvent

; ---------------------------------------------------------------------------
; Screen-reader support
; ---------------------------------------------------------------------------

String Function GetTitle(Int aiIndex)
    If aiIndex < 0
        Return ""
    EndIf
    ; ItemTitle_tf shows the translated title of the focused item.
    String t = ""
    If aiIndex == UI.GetInt(MENU, MC + ".iFocusIndex")
        t = UI.GetString(MENU, MC + ".ItemTitle_tf.text")
    EndIf
    If t == "" || StringUtil.GetNthChar(t, 0) == "$"
        String raw = UI.GetString(MENU, MC + ".data." + aiIndex + ".title")
        If raw != "" && StringUtil.GetNthChar(raw, 0) != "$"
            t = raw
        ElseIf t == ""
            t = raw
        EndIf
    EndIf
    Return t
EndFunction

String Function GetDescription(Int aiIndex)
    String d = UI.GetString(MENU, MC + ".Placeholder_tf.text")
    If d == ""
        d = UI.GetString(MENU, MC + ".data." + aiIndex + ".description")
    EndIf
    Return d
EndFunction

Bool Function IsSelected(Int aiIndex)
    Return UI.GetBool(MENU, ITEMS + aiIndex + ".Highlight_mc._visible")
EndFunction

Function AccessLoop()
    ; The SWF loads JayMenu.json asynchronously; wait for the data (max ~5 s).
    Int tries = 0
    Int count = UI.GetInt(MENU, MC + ".data.length")
    While count <= 0 && tries < 50 && UI.IsMenuOpen(MENU)
        Utility.WaitMenuMode(0.1)
        count = UI.GetInt(MENU, MC + ".data.length")
        tries += 1
    EndWhile

    String header = UI.GetString(MENU, MC + ".Header_tf.text")
    If header == "" || StringUtil.GetNthChar(header, 0) == "$"
        header = "Choose your backstory"
    EndIf
    AccessSpeech.Say(header + ". " + count + " stories in a grid of three columns. Arrow keys to move, Enter to select, right arrow past the last column for the Random and Confirm buttons, Enter on Confirm to finish.", true)

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
                    If selCount > 0
                        AccessSpeech.Say("Confirm button. Starts the selected story.", true)
                    Else
                        AccessSpeech.Say("Confirm button. No story selected yet.", true)
                    EndIf
                ElseIf button == "RandomBtn_mc"
                    AccessSpeech.Say("Random button. Picks a story at random and confirms.", true)
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
            If IsSelected(focus)
                AccessSpeech.Say("Selected " + GetTitle(focus) + ". Move right to Confirm.", true)
            Else
                AccessSpeech.Say("Deselected " + GetTitle(focus), true)
            EndIf
            lastSelCount = selCount
        EndIf

        Utility.WaitMenuMode(0.1)
    EndWhile
EndFunction
