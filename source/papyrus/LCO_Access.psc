Scriptname LCO_Access Hidden
{Access Menu Bridge helper for Lawbringer.
 Lawbringer's prompts are vanilla message boxes. These functions narrate such a box through
 AccessSpeech while it is open: which location this is, who holds it, the box text, the visible
 buttons, and the highlighted button as the player moves. Everything is a no-op without AccessSpeech.dll.

 The box must be opened from another thread (see LCO_SimpleControllerBase.ShowSpoken) because
 Message.Show() blocks the thread that calls it.}

String Function MENU() Global
    Return "MessageBoxMenu"
EndFunction

String Function BTN() Global
    Return "_root.MessageMenu.Buttons.Button"
EndFunction

; Narrates the message box that is about to open. Returns false if no box appeared within ~3 s.
Bool Function NarrateMessageBox(Location akLoc, Keyword akDefaultOwnership, Int aiCurrent, Bool abClaim) Global
    If !AccessSpeech.IsAvailable()
        Return False
    EndIf

    String intro = akLoc.GetName()
    If abClaim
        intro += ", currently held by " + OwnerName(akLoc, akDefaultOwnership, aiCurrent) + "."
    Else
        intro += "."
    EndIf
    AccessSpeech.Say(intro, true)

    ; Wait for the box (it is opened by the controller's event handler on another thread).
    Int tries = 0
    While !UI.IsMenuOpen(MENU()) && tries < 60
        Utility.WaitMenuMode(0.05)
        tries += 1
    EndWhile
    If !UI.IsMenuOpen(MENU())
        Return False
    EndIf
    Utility.WaitMenuMode(0.15)

    String text = UI.GetString(MENU(), "_root.MessageMenu.MessageText.text")

    ; Visible buttons. Hidden (conditioned) buttons leave gaps in the Button0..Button7 names,
    ; so collect the ones that exist into a dense list.
    String[] labels = Utility.CreateStringArray(8)
    Int n = 0
    Int i = 0
    While i < 8
        String l = UI.GetString(MENU(), BTN() + i + ".ButtonText.text")
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

    If abClaim
        AccessSpeech.Say("Raise a banner for: " + options + ". Reset returns it to the default owner. Left and right to move, Enter to choose.", false)
    Else
        AccessSpeech.Say(text + " " + options, false)
    EndIf

    ; Announce the highlighted button whenever it changes. The first focus (set by the box
    ; itself a moment after opening) is not announced so it does not cut off the list above.
    Int last = FocusedButton(n)
    While UI.IsMenuOpen(MENU())
        Int f = FocusedButton(n)
        If f >= 0 && f < n && f != last
            If last >= 0
                AccessSpeech.Say(labels[f] + ". " + (f + 1) + " of " + n, true)
            EndIf
            last = f
        EndIf
        Utility.WaitMenuMode(0.1)
    EndWhile
    Return True
EndFunction

; Index (into the dense visible-button list) of the highlighted button, or -1.
Int Function FocusedButton(Int n) Global
    ; Better MessageBox Controls / SkyUI message box: lastTabIndex tracks the focused button.
    Int idx = UI.GetInt(MENU(), "_root.MessageMenu.lastTabIndex")
    If idx >= 0 && idx < n
        Return idx
    EndIf
    ; Fallback: ask each existing button whether it has focus.
    Int dense = 0
    Int i = 0
    While i < 8
        String l = UI.GetString(MENU(), BTN() + i + ".ButtonText.text")
        If l != "" && l != " "
            If UI.GetInt(MENU(), BTN() + i + ".focused") != 0
                Return dense
            EndIf
            dense += 1
        EndIf
        i += 1
    EndWhile
    Return -1
EndFunction

; Spoken after the box closes.
Function AnnounceResult(Location akLoc, Keyword akDefaultOwnership, Int aiCurrent, Int aiNew) Global
    If !AccessSpeech.IsAvailable()
        Return
    EndIf
    String name = akLoc.GetName()
    If aiNew == aiCurrent
        AccessSpeech.Say("No change. " + name + " stays with " + OwnerName(akLoc, akDefaultOwnership, aiCurrent) + ".", true)
    Else
        AccessSpeech.Say("Banner raised for " + OwnerName(akLoc, akDefaultOwnership, aiNew) + ". " + name + " changes hands in " + RealTimeText() + ", after " + GameTimeText() + " in game, or when you leave the area.", true)
    EndIf
EndFunction

; ---------------------------------------------------------------------------

String Function OwnerName(Location akLoc, Keyword akDefaultOwnership, Int aiOwner) Global
    If aiOwner == 0
        Int def = akLoc.GetKeywordData(akDefaultOwnership) as Int
        If def > 0
            Return "the default owner, " + FactionName(def)
        EndIf
        Return "the default owner"
    EndIf
    Return FactionName(aiOwner)
EndFunction

String Function FactionName(Int aiOwner) Global
    If aiOwner == 2
        Return "the local Hold"
    EndIf
    Return LCO.getFactionName(aiOwner)
EndFunction

String Function RealTimeText() Global
    Float s = LCO.realTimeUpdateDelay()
    If s <= 0.0
        s = 300.0
    EndIf
    If s >= 60.0
        Int m = (s / 60.0) as Int
        If m == 1
            Return "1 minute"
        EndIf
        Return m + " minutes"
    EndIf
    Return (s as Int) + " seconds"
EndFunction

String Function GameTimeText() Global
    Float h = LCO.gameTimeUpdateDelay()
    If h <= 0.0
        h = 24.0
    EndIf
    Int hi = h as Int
    If hi == 1
        Return "1 hour"
    EndIf
    Return hi + " hours"
EndFunction
