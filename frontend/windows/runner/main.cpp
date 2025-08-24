#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <iostream>
#include "flutter_window.h"
#include "utils.h"
#include "window_manager_plus_v2/window_manager_plus_plugin.h" // Убедитесь, что этот инклюд есть

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ LPWSTR cmdline, _In_ int show_cmd) {
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // --- Создание ГЛАВНОГО ОКНА ---
  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(800, 600);
  if (!window.Create(L"Помощник обработки накладных", origin, size)) {
    return EXIT_FAILURE;
  }
  // ГЛАВНОЕ ОКНО ДОЛЖНО ЗАКРЫВАТЬ ПРИЛОЖЕНИЕ
  window.SetQuitOnClose(true);

  // --- Регистрация колбэка для создания ДОЧЕРНИХ ОКОН (Оверлеев) ---
  WindowManagerPlusPluginSetWindowCreatedCallback(
      [](std::vector<std::string> command_line_arguments) {
        flutter::DartProject project(L"data");
        project.set_dart_entrypoint_arguments(std::move(command_line_arguments));
        
        auto window = std::make_shared<FlutterWindow>(project);
        Win32Window::Point origin(10, 10);
        Win32Window::Size size(400, 600);
        if (!window->Create(L"invoice_helper_overlay", origin, size)) {
          std::cerr << "Failed to create a new window" << std::endl;
        }
        // ДОЧЕРНЕЕ ОКНО НЕ ДОЛЖНО ЗАКРЫВАТЬ ПРИЛОЖЕНИЕ
        window->SetQuitOnClose(false);
        return std::move(window);
      });

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}