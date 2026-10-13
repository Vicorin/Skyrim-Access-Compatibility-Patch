#pragma once
#include <string>

// Background speech output. Backends: NVDA controller client (nvdaControllerClient.dll in the
// game folder) when NVDA is running, otherwise Windows SAPI 5. All calls are non-blocking.
namespace Speech
{
	bool Init();
	void Shutdown();

	void Say(const std::wstring& text, bool interrupt);
	void Stop();

	bool IsAvailable();
	const char* BackendName();
}
