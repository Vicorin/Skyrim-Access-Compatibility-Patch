// AccessSpeech - SKSE plugin exposing screen-reader speech to Papyrus.
//
// Papyrus (script AccessSpeech):
//   Function Say(String asText, Bool abInterrupt = true) Global Native
//   Function Stop() Global Native
//   Bool Function IsAvailable() Global Native
//   String Function GetBackendName() Global Native
//   Int Function GetVersion() Global Native
//   String[] Function DescribeBeastPerk(String asLabel) Global Native   (BeastPerks.cpp)
//   String[] Function ListBeastPerks(Int aiTree, Int aiMode) Global Native

#include <shlobj.h>

#include "common/IDebugLog.h"
#include "skse64_common/skse_version.h"
#include "skse64/PluginAPI.h"
#include "skse64/GameTypes.h"
#include "skse64/PapyrusVM.h"
#include "skse64/PapyrusNativeFunctions.h"

#include "Speech.h"
#include "BeastPerks.h"

IDebugLog gLog;

namespace
{
	const UInt32 kPluginVersion = 2;
	const char* kPluginName = "AccessSpeech";
	const char* kPapyrusClass = "AccessSpeech";

	std::wstring ToWide(const char* s)
	{
		if (!s || !*s) return std::wstring();
		int len = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s, -1, nullptr, 0);
		UINT cp = CP_UTF8;
		if (len <= 0)
		{
			cp = CP_ACP;
			len = MultiByteToWideChar(cp, 0, s, -1, nullptr, 0);
			if (len <= 0) return std::wstring();
		}
		std::wstring out((size_t)len, L'\0');
		MultiByteToWideChar(cp, 0, s, -1, &out[0], len);
		while (!out.empty() && out.back() == L'\0') out.pop_back();
		return out;
	}

	void Papyrus_Say(StaticFunctionTag*, BSFixedString text, bool interrupt)
	{
		Speech::Say(ToWide(text.data), interrupt);
	}

	void Papyrus_Stop(StaticFunctionTag*)
	{
		Speech::Stop();
	}

	bool Papyrus_IsAvailable(StaticFunctionTag*)
	{
		return Speech::IsAvailable();
	}

	BSFixedString Papyrus_GetBackendName(StaticFunctionTag*)
	{
		return BSFixedString(Speech::BackendName());
	}

	SInt32 Papyrus_GetVersion(StaticFunctionTag*)
	{
		return (SInt32)kPluginVersion;
	}

	bool RegisterPapyrus(VMClassRegistry* registry)
	{
		registry->RegisterFunction(new NativeFunction2<StaticFunctionTag, void, BSFixedString, bool>("Say", kPapyrusClass, Papyrus_Say, registry));
		registry->RegisterFunction(new NativeFunction0<StaticFunctionTag, void>("Stop", kPapyrusClass, Papyrus_Stop, registry));
		registry->RegisterFunction(new NativeFunction0<StaticFunctionTag, bool>("IsAvailable", kPapyrusClass, Papyrus_IsAvailable, registry));
		registry->RegisterFunction(new NativeFunction0<StaticFunctionTag, BSFixedString>("GetBackendName", kPapyrusClass, Papyrus_GetBackendName, registry));
		registry->RegisterFunction(new NativeFunction0<StaticFunctionTag, SInt32>("GetVersion", kPapyrusClass, Papyrus_GetVersion, registry));

		registry->SetFunctionFlags(kPapyrusClass, "Say", VMClassRegistry::kFunctionFlag_NoWait);
		registry->SetFunctionFlags(kPapyrusClass, "Stop", VMClassRegistry::kFunctionFlag_NoWait);
		registry->SetFunctionFlags(kPapyrusClass, "IsAvailable", VMClassRegistry::kFunctionFlag_NoWait);
		registry->SetFunctionFlags(kPapyrusClass, "GetBackendName", VMClassRegistry::kFunctionFlag_NoWait);
		registry->SetFunctionFlags(kPapyrusClass, "GetVersion", VMClassRegistry::kFunctionFlag_NoWait);

		BeastPerks::RegisterPapyrus(registry, kPapyrusClass);

		_MESSAGE("Papyrus functions registered on %s", kPapyrusClass);
		return true;
	}
}

extern "C"
{
	__declspec(dllexport) SKSEPluginVersionData SKSEPlugin_Version =
	{
		SKSEPluginVersionData::kVersion,
		kPluginVersion,
		"AccessSpeech",
		"Josh",
		"",
		0,	// versionIndependenceEx
		0,	// versionIndependence: built against the SKSE sources for this exact runtime
		{ RUNTIME_VERSION_1_7_104, 0 },
		0,	// seVersionRequired
	};

	__declspec(dllexport) bool SKSEPlugin_Load(const SKSEInterface* skse)
	{
		gLog.OpenRelative(CSIDL_MYDOCUMENTS, "\\My Games\\Skyrim Special Edition\\SKSE\\AccessSpeech.log");
		gLog.SetPrintLevel(IDebugLog::kLevel_Message);
		gLog.SetLogLevel(IDebugLog::kLevel_Message);

		_MESSAGE("%s v%u loading (runtime %08X, SKSE %08X)", kPluginName, kPluginVersion, skse->runtimeVersion, skse->skseVersion);

		if (skse->isEditor)
		{
			_MESSAGE("editor detected, not loading");
			return false;
		}

		SKSEPapyrusInterface* papyrus = (SKSEPapyrusInterface*)skse->QueryInterface(kInterface_Papyrus);
		if (!papyrus)
		{
			_MESSAGE("could not get Papyrus interface");
			return false;
		}
		if (!papyrus->Register(RegisterPapyrus))
		{
			_MESSAGE("Papyrus registration failed");
			return false;
		}

		Speech::Init();
		_MESSAGE("loaded");
		return true;
	}
}
