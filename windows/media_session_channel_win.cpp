// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.
#include "media_session_channel_win.h"

#include <winrt/Windows.Foundation.h>

#include <flutter/event_stream_handler_functions.h>

#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace mpv_audio_kit {

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr UINT kCommandMessage = WM_APP + 1;
const wchar_t* kWindowClass = L"MpvAudioKitMediaSessionMsgWindow";

const EncodableValue* Find(const EncodableMap& m, const char* key) {
  auto it = m.find(EncodableValue(std::string(key)));
  return it == m.end() ? nullptr : &it->second;
}

std::optional<std::string> GetString(const EncodableMap& m, const char* key) {
  if (auto* v = Find(m, key))
    if (auto* s = std::get_if<std::string>(v)) return *s;
  return std::nullopt;
}

std::optional<int64_t> GetInt64(const EncodableMap& m, const char* key) {
  if (auto* v = Find(m, key)) {
    if (auto* i = std::get_if<int64_t>(v)) return *i;
    if (auto* i = std::get_if<int32_t>(v)) return static_cast<int64_t>(*i);
  }
  return std::nullopt;
}

std::optional<double> GetDouble(const EncodableMap& m, const char* key) {
  if (auto* v = Find(m, key)) {
    if (auto* d = std::get_if<double>(v)) return *d;
    if (auto* i = std::get_if<int32_t>(v)) return static_cast<double>(*i);
    if (auto* i = std::get_if<int64_t>(v)) return static_cast<double>(*i);
  }
  return std::nullopt;
}

bool GetBool(const EncodableMap& m, const char* key, bool fallback) {
  if (auto* v = Find(m, key))
    if (auto* b = std::get_if<bool>(v)) return *b;
  return fallback;
}

SmtcConfig ParseConfig(const EncodableMap& m) {
  SmtcConfig c;
  if (auto* v = Find(m, "actions"))
    if (auto* list = std::get_if<EncodableList>(v))
      for (const auto& e : *list)
        if (auto* s = std::get_if<std::string>(&e)) c.actions.insert(*s);
  if (auto s = GetString(m, "interruptionPolicy")) c.interruption_policy = *s;
  if (auto i = GetInt64(m, "fastForwardIntervalMs")) c.fast_forward_ms = *i;
  if (auto i = GetInt64(m, "rewindIntervalMs")) c.rewind_ms = *i;
  if (auto* v = Find(m, "supportedPlaybackRates"))
    if (auto* list = std::get_if<EncodableList>(v))
      for (const auto& e : *list) {
        if (auto* d = std::get_if<double>(&e)) {
          c.supported_rates.push_back(*d);
        } else if (auto* i = std::get_if<int32_t>(&e)) {
          c.supported_rates.push_back(static_cast<double>(*i));
        } else if (auto* i = std::get_if<int64_t>(&e)) {
          c.supported_rates.push_back(static_cast<double>(*i));
        }
      }
  if (auto s = GetString(m, "appName")) c.app_name = *s;
  return c;
}

SmtcMetadata ParseMetadata(const EncodableMap& m) {
  SmtcMetadata md;
  md.title = GetString(m, "title");
  md.artist = GetString(m, "artist");
  md.album = GetString(m, "album");
  if (auto* v = Find(m, "artworkBytes"))
    if (auto* b = std::get_if<std::vector<uint8_t>>(v)) md.artwork = *b;
  md.duration_ms = GetInt64(m, "durationMs");
  return md;
}

SmtcPlayback ParsePlayback(const EncodableMap& m) {
  SmtcPlayback p;
  p.playing = GetBool(m, "playing", false);
  if (auto i = GetInt64(m, "positionMs")) p.position_ms = *i;
  if (auto d = GetDouble(m, "rate")) p.rate = *d;
  p.seekable = GetBool(m, "seekable", false);
  if (auto s = GetString(m, "loop")) p.loop = *s;
  p.shuffle = GetBool(m, "shuffle", false);
  return p;
}

const EncodableMap* SubMap(const EncodableMap& m, const char* key) {
  if (auto* v = Find(m, key)) return std::get_if<EncodableMap>(v);
  return nullptr;
}

}  // namespace

MediaSessionChannelWin::MediaSessionChannelWin(
    flutter::PluginRegistrarWindows* registrar) {
  // SMTC types are agile, but C++/WinRT requires the apartment initialised.
  // Flutter already inits COM on this (platform) thread as STA; match that
  // (init_apartment defaults to MTA, which would just throw RPC_E_CHANGED_MODE
  // and mask the real apartment). The artwork async work runs on its own MTA
  // thread — see MakeThumbnail — since `.get()` is unsafe on this STA thread.
  try {
    winrt::init_apartment(winrt::apartment_type::single_threaded);
  } catch (const winrt::hresult_error&) {
  }

  // Message-only window to marshal OS commands onto the platform thread.
  WNDCLASSW wc{};
  wc.lpfnWndProc = &MediaSessionChannelWin::WndProc;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = kWindowClass;
  RegisterClassW(&wc);  // ignore ERROR_CLASS_ALREADY_EXISTS
  message_window_ =
      CreateWindowExW(0, kWindowClass, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr,
                      wc.hInstance, nullptr);
  if (message_window_) {
    SetWindowLongPtrW(message_window_, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(this));
  }

  controller_ = std::make_unique<SmtcController>(
      [this](EncodableValue command) { ForwardCommand(std::move(command)); });

  method_channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "mpv_audio_kit/media_session",
      &flutter::StandardMethodCodec::GetInstance());
  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  event_channel_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
      registrar->messenger(), "mpv_audio_kit/media_session/commands",
      &flutter::StandardMethodCodec::GetInstance());
  event_channel_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [this](const EncodableValue*,
                 std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            event_sink_ = std::move(events);
            return nullptr;
          },
          [this](const EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            event_sink_.reset();
            return nullptr;
          }));
}

MediaSessionChannelWin::~MediaSessionChannelWin() {
  if (message_window_) {
    DestroyWindow(message_window_);
    message_window_ = nullptr;
  }
}

void MediaSessionChannelWin::ForwardCommand(EncodableValue command) {
  if (!message_window_) return;
  auto* heap = new EncodableValue(std::move(command));
  if (!PostMessageW(message_window_, kCommandMessage, 0,
                    reinterpret_cast<LPARAM>(heap))) {
    delete heap;
  }
}

LRESULT CALLBACK MediaSessionChannelWin::WndProc(HWND hwnd, UINT msg,
                                                 WPARAM wparam, LPARAM lparam) {
  if (msg == kCommandMessage) {
    auto* command = reinterpret_cast<EncodableValue*>(lparam);
    auto* self = reinterpret_cast<MediaSessionChannelWin*>(
        GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (self && self->event_sink_ && command) {
      self->event_sink_->Success(*command);
    }
    delete command;
    return 0;
  }
  return DefWindowProcW(hwnd, msg, wparam, lparam);
}

void MediaSessionChannelWin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto& method = call.method_name();
  const auto* args = std::get_if<EncodableMap>(call.arguments());

  if (method == "enable") {
    if (!args) {
      result->Error("bad_args", "enable expects a map");
      return;
    }
    const EncodableMap* cfg = SubMap(*args, "config");
    const EncodableMap* meta = SubMap(*args, "metadata");
    const EncodableMap* pb = SubMap(*args, "playback");
    controller_->Enable(cfg ? ParseConfig(*cfg) : SmtcConfig{},
                        meta ? ParseMetadata(*meta) : SmtcMetadata{},
                        pb ? ParsePlayback(*pb) : SmtcPlayback{});
    result->Success();
  } else if (method == "updateConfig") {
    if (args) controller_->UpdateConfig(ParseConfig(*args));
    result->Success();
  } else if (method == "updateMetadata") {
    if (args) controller_->UpdateMetadata(ParseMetadata(*args));
    result->Success();
  } else if (method == "updatePlayback") {
    if (args) controller_->UpdatePlayback(ParsePlayback(*args));
    result->Success();
  } else if (method == "disable") {
    controller_->Disable();
    result->Success();
  } else if (method == "debugMediaSessionState") {
    result->Success(controller_->DebugState());
  } else {
    result->NotImplemented();
  }
}

}  // namespace mpv_audio_kit
