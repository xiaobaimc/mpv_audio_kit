// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.
#include "mpris_server.h"

#include <glib/gstdio.h>

#include <cctype>
#include <cstdlib>
#include <cstring>
#include <string>

#include "mpris_introspection.h"

namespace mpv_audio_kit {

namespace {

const char kObjectPath[] = "/org/mpris/MediaPlayer2";
const char kRootIface[] = "org.mpris.MediaPlayer2";
const char kPlayerIface[] = "org.mpris.MediaPlayer2.Player";

std::string FlString(FlValue* map, const char* key) {
  FlValue* v = map ? fl_value_lookup_string(map, key) : nullptr;
  if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
    return fl_value_get_string(v);
  }
  return std::string();
}

bool FlBool(FlValue* map, const char* key, bool fallback) {
  FlValue* v = map ? fl_value_lookup_string(map, key) : nullptr;
  if (v && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) return fl_value_get_bool(v);
  return fallback;
}

bool FlInt(FlValue* map, const char* key, int64_t* out) {
  FlValue* v = map ? fl_value_lookup_string(map, key) : nullptr;
  if (v && fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
    *out = fl_value_get_int(v);
    return true;
  }
  return false;
}

double FlDouble(FlValue* map, const char* key, double fallback) {
  FlValue* v = map ? fl_value_lookup_string(map, key) : nullptr;
  if (!v) return fallback;
  if (fl_value_get_type(v) == FL_VALUE_TYPE_FLOAT) return fl_value_get_float(v);
  if (fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
    return static_cast<double>(fl_value_get_int(v));
  }
  return fallback;
}

const char* LoopToStatus(const std::string& loop) {
  if (loop == "file") return "Track";
  if (loop == "playlist") return "Playlist";
  return "None";
}

std::string StatusToLoop(const char* status) {
  if (status && !strcmp(status, "Track")) return "file";
  if (status && !strcmp(status, "Playlist")) return "playlist";
  return "off";
}

std::string SanitizeBusSuffix(const std::string& in) {
  std::string out;
  for (char c : in) {
    out += std::isalnum(static_cast<unsigned char>(c)) ? c : '_';
  }
  if (out.empty()) return "mpv_audio_kit";
  if (std::isdigit(static_cast<unsigned char>(out[0]))) out = "_" + out;
  return out;
}

}  // namespace

MprisServer::MprisServer(FlEventChannel* event_channel)
    : event_channel_(event_channel) {
  node_info_ = g_dbus_node_info_new_for_xml(kMprisIntrospectionXml, nullptr);
  changed_props_ =
      g_hash_table_new_full(g_str_hash, g_str_equal, g_free, nullptr);
}

MprisServer::~MprisServer() {
  if (flush_source_id_) {
    g_source_remove(flush_source_id_);
    flush_source_id_ = 0;
  }
  ReleaseBus();
  SweepArtwork();
  if (changed_props_) {
    g_hash_table_destroy(changed_props_);
    changed_props_ = nullptr;
  }
  if (node_info_) {
    g_dbus_node_info_unref(node_info_);
    node_info_ = nullptr;
  }
  if (event_channel_) {
    g_object_unref(event_channel_);
    event_channel_ = nullptr;
  }
}

// ── Bus ownership ───────────────────────────────────────────────────────────

void MprisServer::EnsureOwned() {
  if (owner_id_ != 0) return;
  std::string suffix =
      app_name_.empty() ? "mpv_audio_kit" : SanitizeBusSuffix(app_name_);
  std::string bus = "org.mpris.MediaPlayer2." + suffix;
  owner_id_ = g_bus_own_name(G_BUS_TYPE_SESSION, bus.c_str(),
                             G_BUS_NAME_OWNER_FLAGS_NONE, OnBusAcquired, nullptr,
                             OnNameLost, this, nullptr);
}

void MprisServer::ReleaseBus() {
  if (connection_) {
    if (player_reg_id_) {
      g_dbus_connection_unregister_object(connection_, player_reg_id_);
    }
    if (root_reg_id_) {
      g_dbus_connection_unregister_object(connection_, root_reg_id_);
    }
  }
  player_reg_id_ = 0;
  root_reg_id_ = 0;
  if (owner_id_) {
    g_bus_unown_name(owner_id_);
    owner_id_ = 0;
  }
  connection_ = nullptr;
}

void MprisServer::OnBusAcquired(GDBusConnection* connection, const gchar*,
                                gpointer user_data) {
  auto* self = static_cast<MprisServer*>(user_data);
  self->connection_ = connection;
  // The introspection XML is a compile-time constant so parsing won't fail in
  // practice, but guard so a future edit can't silently null-deref here.
  if (self->node_info_ == nullptr) return;

  GDBusInterfaceInfo* root =
      g_dbus_node_info_lookup_interface(self->node_info_, kRootIface);
  GDBusInterfaceInfo* player =
      g_dbus_node_info_lookup_interface(self->node_info_, kPlayerIface);

  static const GDBusInterfaceVTable root_vtable = {RootMethodCall,
                                                   RootGetProperty, nullptr};
  static const GDBusInterfaceVTable player_vtable = {
      PlayerMethodCall, PlayerGetProperty, PlayerSetProperty};

  self->root_reg_id_ = g_dbus_connection_register_object(
      connection, kObjectPath, root, &root_vtable, self, nullptr, nullptr);
  self->player_reg_id_ = g_dbus_connection_register_object(
      connection, kObjectPath, player, &player_vtable, self, nullptr, nullptr);

  self->RepublishAll();
}

void MprisServer::OnNameLost(GDBusConnection* connection, const gchar*,
                             gpointer user_data) {
  // Either the connection couldn't be established, or another instance took
  // the name. If a live connection exists, unregister the objects before
  // forgetting their ids so a later lost→re-acquired cycle doesn't leak them.
  auto* self = static_cast<MprisServer*>(user_data);
  GDBusConnection* conn = self->connection_ ? self->connection_ : connection;
  if (conn) {
    if (self->player_reg_id_) {
      g_dbus_connection_unregister_object(conn, self->player_reg_id_);
    }
    if (self->root_reg_id_) {
      g_dbus_connection_unregister_object(conn, self->root_reg_id_);
    }
  }
  self->connection_ = nullptr;
  self->root_reg_id_ = 0;
  self->player_reg_id_ = 0;
}

// ── Root interface ──────────────────────────────────────────────────────────

void MprisServer::RootMethodCall(GDBusConnection*, const gchar*, const gchar*,
                                 const gchar*, const gchar* /*method*/,
                                 GVariant*, GDBusMethodInvocation* invocation,
                                 gpointer) {
  // Raise / Quit are advertised but no-ops for an embedded audio session.
  g_dbus_method_invocation_return_value(invocation, nullptr);
}

GVariant* MprisServer::RootGetProperty(GDBusConnection*, const gchar*,
                                       const gchar*, const gchar*,
                                       const gchar* property, GError** error,
                                       gpointer user_data) {
  auto* self = static_cast<MprisServer*>(user_data);
  if (!strcmp(property, "CanQuit")) return g_variant_new_boolean(FALSE);
  if (!strcmp(property, "CanRaise")) return g_variant_new_boolean(FALSE);
  if (!strcmp(property, "HasTrackList")) return g_variant_new_boolean(FALSE);
  if (!strcmp(property, "Identity")) {
    return g_variant_new_string(
        self->app_name_.empty() ? "mpv_audio_kit" : self->app_name_.c_str());
  }
  if (!strcmp(property, "DesktopEntry")) {
    // Must be a .desktop basename (no extension / spaces), NOT a display name.
    // Reuse the sanitized bus suffix; fall back to the package id.
    std::string entry = self->app_name_.empty()
                            ? "mpv_audio_kit"
                            : SanitizeBusSuffix(self->app_name_);
    return g_variant_new_string(entry.c_str());
  }
  if (!strcmp(property, "SupportedUriSchemes") ||
      !strcmp(property, "SupportedMimeTypes")) {
    return g_variant_new_strv(nullptr, 0);
  }
  // GDBus requires NULL be paired with a set error, or the call hangs/criticals.
  g_set_error(error, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_PROPERTY,
              "Unknown property: %s", property);
  return nullptr;
}

// ── Player interface ────────────────────────────────────────────────────────

void MprisServer::PlayerMethodCall(GDBusConnection*, const gchar*, const gchar*,
                                   const gchar*, const gchar* method,
                                   GVariant* params,
                                   GDBusMethodInvocation* invocation,
                                   gpointer user_data) {
  auto* self = static_cast<MprisServer*>(user_data);
  if (!strcmp(method, "Next")) {
    self->Emit("next");
  } else if (!strcmp(method, "Previous")) {
    self->Emit("previous");
  } else if (!strcmp(method, "Pause")) {
    self->Emit("pause");
  } else if (!strcmp(method, "Play")) {
    self->Emit("play");
  } else if (!strcmp(method, "PlayPause")) {
    self->Emit("playPause");
  } else if (!strcmp(method, "Stop")) {
    self->Emit("stop");
  } else if (!strcmp(method, "Seek")) {
    gint64 offset_us = 0;
    g_variant_get(params, "(x)", &offset_us);
    FlValue* m = fl_value_new_map();
    fl_value_set_string_take(m, "type", fl_value_new_string("seekBy"));
    fl_value_set_string_take(m, "offsetMs", fl_value_new_int(offset_us / 1000));
    self->EmitWith(m);
  } else if (!strcmp(method, "SetPosition")) {
    const gchar* track_id = nullptr;
    gint64 pos_us = 0;
    g_variant_get(params, "(&ox)", &track_id, &pos_us);
    std::string current =
        std::string("/org/mpris/MediaPlayer2/Track/") +
        std::to_string(self->track_no_);
    if (track_id && current == track_id) {
      FlValue* m = fl_value_new_map();
      fl_value_set_string_take(m, "type", fl_value_new_string("seekTo"));
      fl_value_set_string_take(m, "positionMs", fl_value_new_int(pos_us / 1000));
      self->EmitWith(m);
    }
  }
  // OpenUri and anything else: acknowledged, no-op.
  g_dbus_method_invocation_return_value(invocation, nullptr);
}

GVariant* MprisServer::PlayerPropertyValue(const char* property) {
  if (!strcmp(property, "PlaybackStatus")) {
    return g_variant_new_string(
        !enabled_ ? "Stopped" : (playing_ ? "Playing" : "Paused"));
  }
  if (!strcmp(property, "LoopStatus")) {
    return g_variant_new_string(LoopToStatus(loop_));
  }
  if (!strcmp(property, "Rate")) return g_variant_new_double(rate_);
  if (!strcmp(property, "Shuffle")) return g_variant_new_boolean(shuffle_);
  if (!strcmp(property, "Metadata")) return BuildMetadata();
  if (!strcmp(property, "Volume")) return g_variant_new_double(volume_);
  if (!strcmp(property, "Position")) {
    return g_variant_new_int64(ExtrapolatedPositionUs());
  }
  if (!strcmp(property, "MinimumRate")) return g_variant_new_double(min_rate_);
  if (!strcmp(property, "MaximumRate")) return g_variant_new_double(max_rate_);
  if (!strcmp(property, "CanGoNext")) {
    return g_variant_new_boolean(enabled_ && actions_.count("next") > 0);
  }
  if (!strcmp(property, "CanGoPrevious")) {
    return g_variant_new_boolean(enabled_ && actions_.count("previous") > 0);
  }
  if (!strcmp(property, "CanPlay")) return g_variant_new_boolean(enabled_);
  if (!strcmp(property, "CanPause")) return g_variant_new_boolean(enabled_);
  if (!strcmp(property, "CanSeek")) {
    return g_variant_new_boolean(enabled_ && seekable_ &&
                                 actions_.count("seek") > 0);
  }
  if (!strcmp(property, "CanControl")) return g_variant_new_boolean(TRUE);
  return nullptr;
}

GVariant* MprisServer::PlayerGetProperty(GDBusConnection*, const gchar*,
                                         const gchar*, const gchar*,
                                         const gchar* property, GError** error,
                                         gpointer user_data) {
  GVariant* v =
      static_cast<MprisServer*>(user_data)->PlayerPropertyValue(property);
  if (!v) {
    g_set_error(error, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_PROPERTY,
                "Unknown property: %s", property);
  }
  return v;
}

gboolean MprisServer::PlayerSetProperty(GDBusConnection*, const gchar*,
                                        const gchar*, const gchar*,
                                        const gchar* property, GVariant* value,
                                        GError**, gpointer user_data) {
  auto* self = static_cast<MprisServer*>(user_data);
  if (!strcmp(property, "LoopStatus")) {
    const gchar* s = g_variant_get_string(value, nullptr);
    FlValue* m = fl_value_new_map();
    fl_value_set_string_take(m, "type", fl_value_new_string("setRepeatMode"));
    fl_value_set_string_take(m, "loop",
                             fl_value_new_string(StatusToLoop(s).c_str()));
    self->EmitWith(m);
    return TRUE;
  }
  if (!strcmp(property, "Rate")) {
    double r = g_variant_get_double(value);
    FlValue* m = fl_value_new_map();
    if (r <= 0.0) {
      // MPRIS: a Rate of 0.0 is equivalent to pausing.
      fl_value_set_string_take(m, "type", fl_value_new_string("pause"));
    } else {
      if (r < self->min_rate_) r = self->min_rate_;
      if (r > self->max_rate_) r = self->max_rate_;
      fl_value_set_string_take(m, "type",
                               fl_value_new_string("setPlaybackRate"));
      fl_value_set_string_take(m, "rate", fl_value_new_float(r));
    }
    self->EmitWith(m);
    return TRUE;
  }
  if (!strcmp(property, "Shuffle")) {
    FlValue* m = fl_value_new_map();
    fl_value_set_string_take(m, "type", fl_value_new_string("setShuffle"));
    fl_value_set_string_take(
        m, "shuffle", fl_value_new_bool(g_variant_get_boolean(value)));
    self->EmitWith(m);
    return TRUE;
  }
  // Volume is read-only (advertised `read` in the introspection XML) — there
  // is no volume command in the wire protocol, so a writable slider would be
  // a dead control. Reject any write.
  return FALSE;
}

GVariant* MprisServer::BuildMetadata() {
  GVariantBuilder b;
  g_variant_builder_init(&b, G_VARIANT_TYPE("a{sv}"));
  if (enabled_ && has_title_) {
    std::string track_id =
        std::string("/org/mpris/MediaPlayer2/Track/") +
        std::to_string(track_no_);
    g_variant_builder_add(&b, "{sv}", "mpris:trackid",
                          g_variant_new_object_path(track_id.c_str()));
    if (has_duration_) {
      g_variant_builder_add(&b, "{sv}", "mpris:length",
                            g_variant_new_int64(duration_ms_ * 1000));
    }
    g_variant_builder_add(&b, "{sv}", "xesam:title",
                          g_variant_new_string(title_.c_str()));
    if (!artist_.empty()) {
      const char* arr[] = {artist_.c_str(), nullptr};
      g_variant_builder_add(&b, "{sv}", "xesam:artist",
                            g_variant_new_strv(arr, -1));
    }
    if (!album_.empty()) {
      g_variant_builder_add(&b, "{sv}", "xesam:album",
                            g_variant_new_string(album_.c_str()));
    }
    if (!art_url_.empty()) {
      g_variant_builder_add(&b, "{sv}", "mpris:artUrl",
                            g_variant_new_string(art_url_.c_str()));
    }
  }
  return g_variant_builder_end(&b);
}

// ── Change batching ─────────────────────────────────────────────────────────

void MprisServer::MarkChanged(const char* prop) {
  if (!changed_props_) return;
  g_hash_table_add(changed_props_, g_strdup(prop));
  if (flush_source_id_ == 0) {
    flush_source_id_ = g_idle_add(FlushChangedCb, this);
  }
}

gboolean MprisServer::FlushChangedCb(gpointer user_data) {
  static_cast<MprisServer*>(user_data)->FlushChanged();
  return G_SOURCE_REMOVE;
}

void MprisServer::FlushChanged() {
  flush_source_id_ = 0;
  if (!connection_ || !enabled_) {
    g_hash_table_remove_all(changed_props_);
    return;
  }
  if (g_hash_table_size(changed_props_) == 0) return;

  GVariantBuilder b;
  g_variant_builder_init(&b, G_VARIANT_TYPE("a{sv}"));
  GHashTableIter it;
  gpointer key, val;
  g_hash_table_iter_init(&it, changed_props_);
  while (g_hash_table_iter_next(&it, &key, &val)) {
    const char* prop = static_cast<const char*>(key);
    GVariant* v = PlayerPropertyValue(prop);
    if (v) g_variant_builder_add(&b, "{sv}", prop, v);
  }
  g_hash_table_remove_all(changed_props_);

  GVariant* changed = g_variant_builder_end(&b);
  GVariant* params = g_variant_new(
      "(s@a{sv}@as)", kPlayerIface, changed,
      g_variant_new_array(G_VARIANT_TYPE_STRING, nullptr, 0));
  g_dbus_connection_emit_signal(connection_, nullptr, kObjectPath,
                                "org.freedesktop.DBus.Properties",
                                "PropertiesChanged", params, nullptr);
}

void MprisServer::RepublishAll() {
  static const char* kProps[] = {
      "PlaybackStatus", "LoopStatus",    "Rate",          "Shuffle",
      "Metadata",       "Volume",        "MinimumRate",   "MaximumRate",
      "CanGoNext",      "CanGoPrevious", "CanPlay",       "CanPause",
      "CanSeek"};
  for (const char* p : kProps) MarkChanged(p);
}

// ── Command forwarding ──────────────────────────────────────────────────────

void MprisServer::Emit(const gchar* type) {
  FlValue* m = fl_value_new_map();
  fl_value_set_string_take(m, "type", fl_value_new_string(type));
  EmitWith(m);
}

void MprisServer::EmitWith(FlValue* command) {
  if (event_channel_) {
    fl_event_channel_send(event_channel_, command, nullptr, nullptr);
  }
  fl_value_unref(command);
}

// ── Position extrapolation ──────────────────────────────────────────────────

int64_t MprisServer::ExtrapolatedPositionUs() const {
  int64_t us = base_position_ms_ * 1000;
  if (playing_) {
    gint64 now = g_get_monotonic_time();
    us += static_cast<int64_t>((now - base_monotonic_us_) * rate_);
  }
  if (us < 0) us = 0;
  // Clamp to the track length so a poll past the last update while playing
  // doesn't report Position beyond mpris:length (clients render >100%).
  if (has_duration_) {
    const int64_t max_us = duration_ms_ * 1000;
    if (us > max_us) us = max_us;
  }
  return us;
}

void MprisServer::AnchorPosition() {
  base_position_ms_ = position_ms_;
  base_monotonic_us_ = g_get_monotonic_time();
}

// ── Artwork temp files ──────────────────────────────────────────────────────

void MprisServer::WriteArtwork(const std::vector<uint8_t>& bytes,
                               const std::string& mime) {
  if (bytes.empty()) {
    art_url_.clear();
    has_artwork_ = false;
    art_cache_key_.clear();
    return;
  }
  if (bytes == art_cache_key_) return;  // unchanged

  if (art_dir_.empty()) {
    const char* runtime = g_get_user_runtime_dir();
    art_dir_ = std::string(runtime ? runtime : "/tmp") + "/mpv_audio_kit";
  }
  g_mkdir_with_parents(art_dir_.c_str(), 0700);

  std::string ext = "img";
  if (mime.find("png") != std::string::npos) {
    ext = "png";
  } else if (mime.find("jpeg") != std::string::npos ||
             mime.find("jpg") != std::string::npos) {
    ext = "jpg";
  } else if (mime.find("webp") != std::string::npos) {
    ext = "webp";
  }
  // Unique filename per track — GNOME caches artUrl by URL, so reusing a path
  // would show stale art.
  std::string path = art_dir_ + "/art-" + std::to_string(++art_counter_) + "." +
                     ext;

  GError* err = nullptr;
  if (g_file_set_contents(path.c_str(),
                          reinterpret_cast<const char*>(bytes.data()),
                          static_cast<gssize>(bytes.size()), &err)) {
    if (!prev_art_path_.empty()) g_remove(prev_art_path_.c_str());
    prev_art_path_ = path;
    // Build a correct percent-encoded file:// URI rather than concatenating.
    gchar* uri = g_filename_to_uri(path.c_str(), nullptr, nullptr);
    art_url_ = uri ? uri : ("file://" + path);
    if (uri) g_free(uri);
    has_artwork_ = true;
    art_cache_key_ = bytes;
  } else if (err) {
    g_error_free(err);
  }
}

void MprisServer::SweepArtwork() {
  if (!prev_art_path_.empty()) {
    g_remove(prev_art_path_.c_str());
    prev_art_path_.clear();
  }
  art_url_.clear();
  has_artwork_ = false;
  art_cache_key_.clear();
}

// ── Public state ops ────────────────────────────────────────────────────────

void MprisServer::Enable(FlValue* config, FlValue* metadata, FlValue* playback) {
  // config
  actions_.clear();
  FlValue* acts = config ? fl_value_lookup_string(config, "actions") : nullptr;
  if (acts && fl_value_get_type(acts) == FL_VALUE_TYPE_LIST) {
    size_t n = fl_value_get_length(acts);
    for (size_t i = 0; i < n; i++) {
      FlValue* e = fl_value_get_list_value(acts, i);
      if (fl_value_get_type(e) == FL_VALUE_TYPE_STRING) {
        actions_.insert(fl_value_get_string(e));
      }
    }
  }
  app_name_ = FlString(config, "appName");
  // supportedPlaybackRates → MinimumRate/MaximumRate. A Dart List<double>
  // arrives as a generic list (FL_VALUE_TYPE_LIST); a Float64List would arrive
  // as FL_VALUE_TYPE_FLOAT_LIST — handle both.
  FlValue* rates =
      config ? fl_value_lookup_string(config, "supportedPlaybackRates")
             : nullptr;
  if (rates && fl_value_get_length(rates) > 0) {
    FlValueType rt = fl_value_get_type(rates);
    size_t n = fl_value_get_length(rates);
    double mn = 0, mx = 0;
    bool first = true;
    for (size_t i = 0; i < n; i++) {
      double r;
      if (rt == FL_VALUE_TYPE_FLOAT_LIST) {
        r = fl_value_get_float_list(rates)[i];
      } else if (rt == FL_VALUE_TYPE_LIST) {
        FlValue* e = fl_value_get_list_value(rates, i);
        FlValueType et = fl_value_get_type(e);
        if (et == FL_VALUE_TYPE_FLOAT) {
          r = fl_value_get_float(e);
        } else if (et == FL_VALUE_TYPE_INT) {
          r = static_cast<double>(fl_value_get_int(e));
        } else {
          continue;
        }
      } else {
        break;
      }
      if (first) {
        mn = mx = r;
        first = false;
      } else {
        if (r < mn) mn = r;
        if (r > mx) mx = r;
      }
    }
    if (!first) {
      min_rate_ = mn;
      max_rate_ = mx;
    }
  }

  UpdateMetadata(metadata);  // parses metadata + writes artwork
  // playback (anchor without seek detection on enable)
  playing_ = FlBool(playback, "playing", false);
  int64_t pos = 0;
  if (FlInt(playback, "positionMs", &pos)) position_ms_ = pos;
  rate_ = FlDouble(playback, "rate", 1.0);
  seekable_ = FlBool(playback, "seekable", false);
  loop_ = FlString(playback, "loop");
  if (loop_.empty()) loop_ = "off";
  shuffle_ = FlBool(playback, "shuffle", false);
  AnchorPosition();

  enabled_ = true;
  EnsureOwned();
  RepublishAll();
  ++publish_count_;
}

void MprisServer::UpdateConfig(FlValue* config) {
  actions_.clear();
  FlValue* acts = config ? fl_value_lookup_string(config, "actions") : nullptr;
  if (acts && fl_value_get_type(acts) == FL_VALUE_TYPE_LIST) {
    size_t n = fl_value_get_length(acts);
    for (size_t i = 0; i < n; i++) {
      FlValue* e = fl_value_get_list_value(acts, i);
      if (fl_value_get_type(e) == FL_VALUE_TYPE_STRING) {
        actions_.insert(fl_value_get_string(e));
      }
    }
  }
  // Note: the bus name is fixed at first Enable; an appName change mid-session
  // does not rename it.
  if (enabled_) {
    MarkChanged("CanGoNext");
    MarkChanged("CanGoPrevious");
    MarkChanged("CanPlay");
    MarkChanged("CanPause");
    MarkChanged("CanSeek");
  }
  ++publish_count_;
}

void MprisServer::UpdateMetadata(FlValue* metadata) {
  std::string new_title = FlString(metadata, "title");
  bool new_has_title = !new_title.empty();
  // A title change implies a new track → bump the trackid object path.
  if (new_has_title && new_title != title_) track_no_++;
  title_ = new_title;
  has_title_ = new_has_title;
  artist_ = FlString(metadata, "artist");
  album_ = FlString(metadata, "album");

  int64_t dur = 0;
  if (FlInt(metadata, "durationMs", &dur)) {
    duration_ms_ = dur;
    has_duration_ = dur > 0;
  } else {
    has_duration_ = false;
  }

  FlValue* art =
      metadata ? fl_value_lookup_string(metadata, "artworkBytes") : nullptr;
  std::string mime = FlString(metadata, "artworkMime");
  if (art && fl_value_get_type(art) == FL_VALUE_TYPE_UINT8_LIST) {
    size_t n = fl_value_get_length(art);
    const uint8_t* d = fl_value_get_uint8_list(art);
    WriteArtwork(std::vector<uint8_t>(d, d + n), mime);
  } else {
    WriteArtwork({}, "");
  }

  if (enabled_) MarkChanged("Metadata");
  ++publish_count_;
}

void MprisServer::UpdatePlayback(FlValue* playback) {
  // Detect a seek against the position we'd have extrapolated to by now,
  // BEFORE re-anchoring.
  int64_t new_pos_ms = 0;
  bool have_pos = FlInt(playback, "positionMs", &new_pos_ms);
  int64_t expected_us = ExtrapolatedPositionUs();

  playing_ = FlBool(playback, "playing", false);
  if (have_pos) position_ms_ = new_pos_ms;
  rate_ = FlDouble(playback, "rate", 1.0);
  seekable_ = FlBool(playback, "seekable", false);
  loop_ = FlString(playback, "loop");
  if (loop_.empty()) loop_ = "off";
  shuffle_ = FlBool(playback, "shuffle", false);

  int64_t new_us = position_ms_ * 1000;
  bool seeked = have_pos && llabs(new_us - expected_us) > 1000000;
  AnchorPosition();

  if (enabled_) {
    MarkChanged("PlaybackStatus");
    MarkChanged("Rate");
    MarkChanged("LoopStatus");
    MarkChanged("Shuffle");
    MarkChanged("CanSeek");
    if (seeked && connection_) {
      g_dbus_connection_emit_signal(connection_, nullptr, kObjectPath,
                                    kPlayerIface, "Seeked",
                                    g_variant_new("(x)", new_us), nullptr);
    }
  }
  ++publish_count_;
}

void MprisServer::Disable() {
  enabled_ = false;
  ReleaseBus();  // drop off the session bus → the entry disappears.
  SweepArtwork();
  if (flush_source_id_) {
    g_source_remove(flush_source_id_);
    flush_source_id_ = 0;
  }
  if (changed_props_) g_hash_table_remove_all(changed_props_);

  actions_.clear();
  app_name_.clear();
  title_.clear();
  artist_.clear();
  album_.clear();
  has_title_ = false;
  duration_ms_ = 0;
  has_duration_ = false;
  playing_ = false;
  position_ms_ = 0;
  rate_ = 1.0;
  seekable_ = false;
  loop_ = "off";
  shuffle_ = false;
  // Reset rate bounds / volume so a later Enable() without supportedPlaybackRates
  // doesn't advertise stale bounds from the previous session.
  min_rate_ = 0.5;
  max_rate_ = 2.0;
  volume_ = 1.0;
  ++publish_count_;
}

FlValue* MprisServer::DebugState() {
  FlValue* m = fl_value_new_map();
  fl_value_set_string_take(m, "publishCount", fl_value_new_int(publish_count_));
  const char* state =
      !enabled_ ? "stopped" : (playing_ ? "playing" : "paused");
  fl_value_set_string_take(m, "playbackState", fl_value_new_string(state));

  bool active = enabled_ && has_title_;
  fl_value_set_string_take(
      m, "title",
      active ? fl_value_new_string(title_.c_str()) : fl_value_new_null());
  fl_value_set_string_take(m, "artist",
                           (active && !artist_.empty())
                               ? fl_value_new_string(artist_.c_str())
                               : fl_value_new_null());
  fl_value_set_string_take(m, "album",
                           (active && !album_.empty())
                               ? fl_value_new_string(album_.c_str())
                               : fl_value_new_null());
  fl_value_set_string_take(
      m, "durationMs",
      has_duration_ ? fl_value_new_int(duration_ms_) : fl_value_new_null());
  fl_value_set_string_take(m, "positionMs", fl_value_new_int(position_ms_));
  fl_value_set_string_take(m, "rate", fl_value_new_float(rate_));
  fl_value_set_string_take(m, "hasArtwork", fl_value_new_bool(has_artwork_));
  fl_value_set_string_take(m, "seekable", fl_value_new_bool(seekable_));
  fl_value_set_string_take(m, "loop", fl_value_new_string(loop_.c_str()));
  fl_value_set_string_take(m, "shuffle", fl_value_new_bool(shuffle_));
  return m;
}

}  // namespace mpv_audio_kit
