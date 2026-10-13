#include "Speech.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <sapi.h>
#include <atomic>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <thread>

#include "common/IDebugLog.h"

namespace
{
	// ---- NVDA controller client ------------------------------------------------------------
	typedef unsigned long (__stdcall* nvda_testIfRunning_t)(void);
	typedef unsigned long (__stdcall* nvda_speakText_t)(const wchar_t*);
	typedef unsigned long (__stdcall* nvda_cancelSpeech_t)(void);

	HMODULE g_nvdaDll = nullptr;
	nvda_testIfRunning_t g_nvdaTest = nullptr;
	nvda_speakText_t g_nvdaSpeak = nullptr;
	nvda_cancelSpeech_t g_nvdaCancel = nullptr;

	// ---- SAPI ------------------------------------------------------------------------------
	ISpVoice* g_sapi = nullptr;
	bool g_comInit = false;

	// ---- worker ----------------------------------------------------------------------------
	struct Utterance
	{
		std::wstring text;
		bool interrupt;
		bool stopOnly;
	};

	std::thread g_thread;
	std::mutex g_mutex;
	std::condition_variable g_cv;
	std::deque<Utterance> g_queue;
	std::atomic<bool> g_running{ false };
	std::atomic<bool> g_available{ false };
	std::atomic<int> g_backend{ 0 }; // 0 none, 1 NVDA, 2 SAPI

	enum Preference { kAuto, kNvda, kSapi };
	Preference g_pref = kAuto;

	std::wstring GetGameDir()
	{
		wchar_t buf[MAX_PATH * 2] = { 0 };
		GetModuleFileNameW(nullptr, buf, (DWORD)(sizeof(buf) / sizeof(buf[0])));
		std::wstring p(buf);
		size_t slash = p.find_last_of(L"\\/");
		return (slash == std::wstring::npos) ? L"." : p.substr(0, slash);
	}

	void ReadConfig()
	{
		std::wstring ini = GetGameDir() + L"\\Data\\SKSE\\Plugins\\AccessSpeech.ini";
		wchar_t val[64] = { 0 };
		GetPrivateProfileStringW(L"General", L"Backend", L"auto", val, 64, ini.c_str());
		std::wstring v(val);
		for (auto& c : v) c = (wchar_t)towlower(c);
		if (v == L"nvda") g_pref = kNvda;
		else if (v == L"sapi") g_pref = kSapi;
		else g_pref = kAuto;
		_MESSAGE("Config: Backend=%ls (from %ls)", v.c_str(), ini.c_str());
	}

	bool LoadNvda()
	{
		const std::wstring dir = GetGameDir();
		const wchar_t* candidates[] = {
			L"\\nvdaControllerClient.dll",
			L"\\nvdaControllerClient64.dll",
			L"\\Data\\SKSE\\Plugins\\AccessSpeech\\nvdaControllerClient.dll",
			L"\\Data\\SKSE\\Plugins\\nvdaControllerClient.dll",
		};
		for (const wchar_t* c : candidates)
		{
			std::wstring path = dir + c;
			g_nvdaDll = LoadLibraryW(path.c_str());
			if (g_nvdaDll)
			{
				_MESSAGE("NVDA: loaded %ls", path.c_str());
				break;
			}
		}
		if (!g_nvdaDll)
		{
			g_nvdaDll = LoadLibraryW(L"nvdaControllerClient.dll");
			if (g_nvdaDll) _MESSAGE("NVDA: loaded from search path");
		}
		if (!g_nvdaDll)
		{
			_MESSAGE("NVDA: controller client not found");
			return false;
		}
		g_nvdaTest = (nvda_testIfRunning_t)GetProcAddress(g_nvdaDll, "nvdaController_testIfRunning");
		g_nvdaSpeak = (nvda_speakText_t)GetProcAddress(g_nvdaDll, "nvdaController_speakText");
		g_nvdaCancel = (nvda_cancelSpeech_t)GetProcAddress(g_nvdaDll, "nvdaController_cancelSpeech");
		if (!g_nvdaTest || !g_nvdaSpeak || !g_nvdaCancel)
		{
			_MESSAGE("NVDA: exports missing");
			return false;
		}
		return true;
	}

	bool NvdaRunning()
	{
		return g_nvdaTest && g_nvdaTest() == 0;
	}

	bool InitSapi()
	{
		HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
		g_comInit = SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE;
		hr = CoCreateInstance(CLSID_SpVoice, nullptr, CLSCTX_ALL, IID_ISpVoice, (void**)&g_sapi);
		if (FAILED(hr) || !g_sapi)
		{
			_MESSAGE("SAPI: CoCreateInstance failed 0x%08X", (unsigned)hr);
			g_sapi = nullptr;
			return false;
		}
		_MESSAGE("SAPI: voice created");
		return true;
	}

	void Deliver(const Utterance& u)
	{
		const bool wantNvda = (g_pref != kSapi) && NvdaRunning();
		if (wantNvda)
		{
			g_backend = 1;
			if (u.interrupt || u.stopOnly) g_nvdaCancel();
			if (!u.stopOnly) g_nvdaSpeak(u.text.c_str());
			return;
		}
		if (g_pref != kNvda && g_sapi)
		{
			g_backend = 2;
			if (u.stopOnly)
			{
				g_sapi->Speak(L"", SPF_ASYNC | SPF_PURGEBEFORESPEAK, nullptr);
				return;
			}
			DWORD flags = SPF_ASYNC | SPF_IS_NOT_XML;
			if (u.interrupt) flags |= SPF_PURGEBEFORESPEAK;
			g_sapi->Speak(u.text.c_str(), flags, nullptr);
			return;
		}
		g_backend = 0;
	}

	void Worker()
	{
		ReadConfig();
		bool nvda = LoadNvda();
		bool sapi = false;
		if (g_pref != kNvda) sapi = InitSapi();
		g_available = (nvda && NvdaRunning()) || sapi || nvda;
		_MESSAGE("Speech: nvda=%d (running=%d) sapi=%d pref=%d", (int)nvda, (int)NvdaRunning(), (int)sapi, (int)g_pref);

		for (;;)
		{
			Utterance u;
			{
				std::unique_lock<std::mutex> lock(g_mutex);
				g_cv.wait(lock, [] { return !g_queue.empty() || !g_running; });
				if (!g_running && g_queue.empty()) break;
				u = std::move(g_queue.front());
				g_queue.pop_front();
			}
			Deliver(u);
		}

		if (g_sapi) { g_sapi->Release(); g_sapi = nullptr; }
		if (g_comInit) CoUninitialize();
	}
}

namespace Speech
{
	bool Init()
	{
		if (g_running) return true;
		g_running = true;
		g_thread = std::thread(Worker);
		return true;
	}

	void Shutdown()
	{
		if (!g_running) return;
		g_running = false;
		g_cv.notify_all();
		if (g_thread.joinable()) g_thread.join();
	}

	void Say(const std::wstring& text, bool interrupt)
	{
		if (text.empty()) return;
		{
			std::lock_guard<std::mutex> lock(g_mutex);
			if (interrupt) g_queue.clear();
			g_queue.push_back(Utterance{ text, interrupt, false });
		}
		g_cv.notify_one();
	}

	void Stop()
	{
		{
			std::lock_guard<std::mutex> lock(g_mutex);
			g_queue.clear();
			g_queue.push_back(Utterance{ std::wstring(), true, true });
		}
		g_cv.notify_one();
	}

	bool IsAvailable()
	{
		return g_available;
	}

	const char* BackendName()
	{
		if (!g_available) return "none";
		if (g_pref != kSapi && NvdaRunning()) return "NVDA";
		if (g_sapi) return "SAPI";
		return "none";
	}
}
