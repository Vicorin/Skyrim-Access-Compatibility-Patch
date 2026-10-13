// Console smoke test for the speech backend (no game needed).
// Usage: SpeechTest.exe [text]
#include "Speech.h"
#include <windows.h>
#include <shlobj.h>
#include <cstdio>
#include <string>

IDebugLog gLog;

int wmain(int argc, wchar_t** argv)
{
	gLog.OpenRelative(CSIDL_MYDOCUMENTS, "\\My Games\\Skyrim Special Edition\\SKSE\\AccessSpeech_test.log");
	gLog.SetPrintLevel(IDebugLog::kLevel_Message);
	gLog.SetLogLevel(IDebugLog::kLevel_Message);

	std::wstring text = argc > 1 ? argv[1] : L"Access Speech test. The bridge is working.";
	Speech::Init();
	Sleep(500); // let the worker initialise backends
	wprintf(L"available=%d backend=%hs\n", (int)Speech::IsAvailable(), Speech::BackendName());
	Speech::Say(text, true);
	Sleep(4000);
	Speech::Shutdown();
	return Speech::IsAvailable() ? 0 : 1;
}
