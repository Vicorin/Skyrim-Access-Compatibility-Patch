Scriptname LCO_SimpleControllerBase extends LCO_LocationControllerBase
{a template for the simple controller type. Player finds a banner, activates it, and is prompted to claim the Location.
 Access Menu Bridge patch: identical to the Lawbringer original, except that the message boxes are
 opened through ShowSpoken(), which narrates them via LCO_Access / AccessSpeech (location, current
 owner, visible buttons, highlighted button) and announces the result. Covers every simple
 controller (HIS, RFIS, VampiresAndSuch, Dragon Bridge Overlook). Without AccessSpeech.dll the
 boxes are shown exactly as in the original.}

;/inherited properties
Keyword CurrentOwnership
Keyword DefaultOwnership
Keyword ChangeOwnership
int newOwner
int defaultOwner
GlobalVariable realTimeUpdateDelay
GlobalVariable gameTimeUpdateDelay
Location thisLocation
/;

Message Property Claim Auto
{Message is displayed when Player activates the Controller, and Player selects a new owner.}
Message property NoClaim Auto
{Message is displayed when Player activates the Controller and is in combat, or the Location is not cleared.}
Message property QuestLocked Auto
{Message is displayed when Player activates the Controller and the Quest Lock's stage to claim has not been set.}
ObjectReference Property ClaimingEnableParent Auto
{This object is disabled when the Quest Lock hides the controller. It is enabled when the controller is unhidden.}

LCO_QuestLock myQuestLock

; --- Access Menu Bridge ---
Message mAccessMsg
Int iAccessResult
Bool bAccessDone

Event OnLoad()
	myQuestLock = (self as ObjectReference) as LCO_QuestLock
	getLocalBanners()
	if(myQuestLock && !myQuestLock.shouldShow())
		hide()
	else
		unhide()
	endIf
endEvent

Event OnActivate(ObjectReference akActionRef)
	int currentOwner = thisLocation.getKeywordData(CurrentOwnership) as int
	if((akActionRef as Actor).isInCombat() || !thisLocation.isCleared())
		ShowSpoken(NoClaim, false, currentOwner)
		return
	endIf
	if(myQuestLock && !myQuestLock.canClaim())
		ShowSpoken(QuestLocked, false, currentOwner)
		return
	endIf
	int selectedOwner = processChoice(ShowSpoken(Claim, true, currentOwner), currentOwner)
	if(selectedOwner != currentOwner)
		newOwner = selectedOwner
		updateBanners(newOwner)
		goToState("UpdateQueued")
	else
		newOwner = currentOwner
		updateBanners(currentOwner)
		goToState("Waiting")
	endIf
	LCO_Access.AnnounceResult(thisLocation, DefaultOwnership, currentOwner, selectedOwner)
endEvent

; Shows akMsg like akMsg.show(), but narrated. Message.Show() blocks its caller, so the box is
; opened by OnAccessShowMessage on a second thread (triggered through a mod event) while this
; thread reads the box and speaks.
Int Function ShowSpoken(Message akMsg, Bool abClaim, Int aiCurrent)
	If !AccessSpeech.IsAvailable()
		Return akMsg.show()
	EndIf
	mAccessMsg = akMsg
	bAccessDone = False
	iAccessResult = -1
	RegisterForModEvent("LCO_Access_ShowMessage", "OnAccessShowMessage")
	SendModEvent("LCO_Access_ShowMessage")
	Bool seen = LCO_Access.NarrateMessageBox(thisLocation, DefaultOwnership, aiCurrent, abClaim)
	Int tries = 0
	While !bAccessDone && tries < 100
		Utility.WaitMenuMode(0.05)
		tries += 1
	EndWhile
	UnregisterForModEvent("LCO_Access_ShowMessage")
	If !bAccessDone
		If seen
			Return -1
		EndIf
		; the event never arrived: fall back to the plain box
		Return akMsg.show()
	EndIf
	Return iAccessResult
EndFunction

Event OnAccessShowMessage(String eventName, String strArg, Float numArg, Form sender)
	If sender != (self as Form) || mAccessMsg == None
		Return
	EndIf
	Message m = mAccessMsg
	mAccessMsg = None
	iAccessResult = m.show()
	bAccessDone = True
EndEvent

function getLocalBanners()
endFunction

int function processChoice(int selectedChoice, int currentOwner)
endFunction

function hide()
	setDisplayName("")
	ClaimingEnableParent.disableNoWait()
endFunction

function unhide()
	setDisplayName(thisLocation.getName())
	ClaimingEnableParent.enableNoWait()
	updateBanners()
endFunction

function updateBanners(int i = -1)
endFunction
