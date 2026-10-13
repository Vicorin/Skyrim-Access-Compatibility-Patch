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

; Plugin version number (1 = first release).
Int Function GetVersion() Global Native
