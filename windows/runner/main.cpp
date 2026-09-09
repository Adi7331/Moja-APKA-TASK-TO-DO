#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "app_links/app_links_plugin_c_api.h"

namespace {

void SetCurrentUserRegistryValue(const std::wstring& key,
                                 const wchar_t* value_name,
                                 const std::wstring& value) {
  RegSetKeyValueW(HKEY_CURRENT_USER, key.c_str(), value_name, REG_SZ,
                  value.c_str(),
                  static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
}

void RegisterDzienPoDniuProtocol() {
  wchar_t executable_path[MAX_PATH] = {};
  const DWORD length = GetModuleFileNameW(nullptr, executable_path, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return;
  }

  const std::wstring base_key = L"SOFTWARE\\Classes\\dzienpodniu";
  const std::wstring executable(executable_path, length);
  const std::wstring command = L"\"" + executable + L"\" \"%1\"";

  SetCurrentUserRegistryValue(base_key, nullptr,
                              L"URL:Dzień po dniu protocol");
  SetCurrentUserRegistryValue(base_key, L"URL Protocol", L"");
  SetCurrentUserRegistryValue(base_key + L"\\shell\\open\\command", nullptr,
                              command);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  RegisterDzienPoDniuProtocol();

  // A custom OAuth URL starts a second executable instance on Windows. Forward
  // it to the running app so Supabase can exchange it for the saved session.
  if (SendAppLinkToInstance()) {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"dzien_po_dniu", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
