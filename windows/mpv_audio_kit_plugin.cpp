// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.
#include "mpv_audio_kit_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace mpv_audio_kit {

namespace {

/**
 * @brief Stub media-session method channel handler.
 *
 * Logs the call via OutputDebugStringA and acks success. Real SMTC
 * wiring lands in Phase 5; this stub exists so the Dart-side
 * MediaSessionController doesn't surface MissingPluginException on
 * Windows desktop builds.
 */
void HandleMediaSessionMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::ostringstream oss;
  oss << "[mpv_audio_kit] media_session stub call: " << call.method_name()
      << "\n";
  OutputDebugStringA(oss.str().c_str());

  const auto& method = call.method_name();
  if (method == "enable" || method == "updateConfig" ||
      method == "updateMetadata" || method == "updatePlayback" ||
      method == "disable") {
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace


/**
 * @brief Static method to register the plugin with the Windows registrar.
 * 
 * Sets up the MethodChannel and the plugin instance.
 * 
 * @param registrar The Windows plugin registrar.
 */
void MpvAudioKitPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "mpv_audio_kit",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<MpvAudioKitPlugin>();

  // Set the method call handler for the channel.
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  // ── Media-session channels ──────────────────────────────────────────
  // Separate method + event channels for the OS media-session bridge.
  // Stubs for now — Phase 5 wires the real SMTC (SystemMedia
  // TransportControls) integration via C++/WinRT.
  auto media_session_method =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "mpv_audio_kit/media_session",
          &flutter::StandardMethodCodec::GetInstance());
  media_session_method->SetMethodCallHandler(
      [](const auto &call, auto result) {
        HandleMediaSessionMethodCall(call, std::move(result));
      });
  // Channel ownership: the lambda captures plugin-lifetime state by
  // value, and the unique_ptr lives in static storage tied to the
  // registrar — leaked deliberately for plugin lifetime, matching
  // the pattern Flutter uses for its own per-plugin channels.
  static auto media_session_method_storage = std::move(media_session_method);

  auto media_session_events =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "mpv_audio_kit/media_session/commands",
          &flutter::StandardMethodCodec::GetInstance());
  media_session_events->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [](const flutter::EncodableValue *arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>
                 &&events)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            OutputDebugStringA(
                "[mpv_audio_kit] media_session commands stream listener "
                "attached\n");
            // No events yet — emitter is wired in Phase 5.
            return nullptr;
          },
          [](const flutter::EncodableValue *arguments)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            OutputDebugStringA(
                "[mpv_audio_kit] media_session commands stream listener "
                "cancelled\n");
            return nullptr;
          }));
  static auto media_session_events_storage = std::move(media_session_events);

  // Add the plugin instance to the registrar.
  registrar->AddPlugin(std::move(plugin));
}

MpvAudioKitPlugin::MpvAudioKitPlugin() {}

MpvAudioKitPlugin::~MpvAudioKitPlugin() {}

/**
 * @brief Handles method calls from Dart via the MethodChannel.
 * 
 * Like other platforms, this plugin primarily uses direct FFI/C bindings to libmpv,
 * so this handler remains minimal for now.
 * 
 * @param method_call The incoming method call from Dart.
 * @param result The result object to send a response back.
 */
void MpvAudioKitPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Platform-specific methods are not yet implemented on Windows.
  result->NotImplemented();
}

}  // namespace mpv_audio_kit
