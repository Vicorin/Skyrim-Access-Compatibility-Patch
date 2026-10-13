scriptname LCO_ShorsWatchtowerController extends LCO_LocationControllerBase
{Access Menu Bridge patch: identical to the Lawbringer original, except that the message boxes are
 opened through ShowSpoken(), which narrates them via LCO_Access / AccessSpeech and announces the result.}

ObjectReference Property RiftGarrisonMarker Auto
ObjectReference Property ImperialGarrisonMarker Auto
ObjectReference Property DefaultRiftMarker Auto
ObjectReference Property DefaultImperialMarker Auto

ObjectReference Property RiftBanner Auto
ObjectReference Property ImperialBanner Auto
ObjectReference Property StormcloakBanner Auto

Actor Property PlayerRef Auto
Message Property Claim Auto
Message Property NoClaim Auto

; --- Access Menu Bridge ---
Message mAccessMsg
Int iAccessResult
Bool bAccessDone

function updateDefaultMarkers()
	if(newOwner == LCO.Default())
		if(RiftGarrisonMarker.isDisabled())
			DefaultRiftMarker.disableNoWait()
		else
			DefaultRiftMarker.enableNoWait()
		endIf
		if(ImperialGarrisonMarker.isDisabled())
			DefaultImperialMarker.disableNoWait()
		else
			DefaultImperialMarker.enableNoWait()
		endIf
	else
		DefaultRiftMarker.disableNoWait()
		DefaultImperialMarker.disableNoWait()
	endIf
endFunction

Event OnLoad()
	updateDefaultMarkers()
	updateBanners()
endEvent

Event OnActivate(ObjectReference ref)
	if(ref == PlayerRef)
		int currentOwner = thisLocation.getKeywordData(CurrentOwnership) as int
		if(PlayerRef.isInCombat())
			ShowSpoken(NoClaim, false, currentOwner)
		else
			int choice = ShowSpoken(Claim, true, currentOwner)
			int selectedOwner = currentOwner
			if(choice == 0)
				newOwner = LCO.Default()
				selectedOwner = newOwner
				goToState("UpdateQueued")
			elseif(choice == 1)
				newOwner = LCO.LocalHold()
				selectedOwner = newOwner
				goToState("UpdateQueued")
			elseif(choice == 2)
				newOwner = LCO.Imperial()
				selectedOwner = newOwner
				goToState("UpdateQueued")
			elseif(choice == 3)
				newOwner = LCO.Stormcloak()
				selectedOwner = newOwner
				goToState("UpdateQueued")
			endIf
			updateBanners()
			LCO_Access.AnnounceResult(thisLocation, DefaultOwnership, currentOwner, selectedOwner)
		endIf
	endIf
endEvent

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

function updateOwnership()
	parent.updateOwnership()
	updateDefaultMarkers()
endFunction

function updateBanners()
	if(newOwner == LCO.Default())
		if(RiftGarrisonMarker.isDisabled())
			RiftBanner.disableNoWait()
		else
			RiftBanner.enableNoWait()
		endIf
		if(ImperialGarrisonMarker.isDisabled())
			ImperialBanner.disableNoWait()
		else
			ImperialBanner.enableNoWait()
		endIf
		StormcloakBanner.disableNoWait()
	elseif(newOwner == LCO.LocalHold())
		RiftBanner.enableNoWait()
		ImperialBanner.disableNoWait()
		StormcloakBanner.disableNoWait()
	elseif(newOwner == LCO.Imperial())
		RiftBanner.disableNoWait()
		ImperialBanner.enableNoWait()
		StormcloakBanner.disableNoWait()
	elseif(newOwner == LCO.Stormcloak())
		RiftBanner.disableNoWait()
		ImperialBanner.disableNoWait()
		StormcloakBanner.enableNoWait()
	endIf
endFunction
