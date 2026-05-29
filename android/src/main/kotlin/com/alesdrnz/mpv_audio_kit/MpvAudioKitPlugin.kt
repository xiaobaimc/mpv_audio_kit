/*
 * Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.
 */
package com.alesdrnz.mpv_audio_kit

import android.content.Context
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** 
 * MpvAudioKitPlugin
 * 
 * Android implementation for mpv_audio_kit.
 */
class MpvAudioKitPlugin :
    FlutterPlugin,
    MethodCallHandler {

    companion object {
        init {
            // Loading libmpv.so via System.loadLibrary() ensures that the JVM
            // invokes libmpv's JNI_OnLoad, registering the JavaVM pointer internally.
            // Without this, dart:ffi loads it via dlopen() which skips JNI_OnLoad,
            // causing the AudioTrack audio output driver to fail with
            // "No Java virtual machine has been registered".
            System.loadLibrary("mpv")
        }
    }

    private lateinit var channel: MethodChannel
    private lateinit var mediaSessionMethodChannel: MethodChannel
    private lateinit var mediaSessionEventChannel: EventChannel
    private val mediaSessionHandler = MediaSessionStubHandler()
    private lateinit var context: Context

    /**
     * Initializes the plugin when attached to the Flutter engine.
     */
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "mpv_audio_kit")
        channel.setMethodCallHandler(this)

        // Media-session sub-channels. Stubs for now — Phase 6 wires
        // the real MediaSessionCompat + foreground service + audio
        // focus integration.
        mediaSessionMethodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "mpv_audio_kit/media_session"
        )
        mediaSessionMethodChannel.setMethodCallHandler(mediaSessionHandler)

        mediaSessionEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "mpv_audio_kit/media_session/commands"
        )
        mediaSessionEventChannel.setStreamHandler(mediaSessionHandler)
    }

    /**
     * Handles MethodChannel calls from Dart.
     * 
     * Significant work on Android includes handling Content URIs (e.g., from the file picker)
     * by converting them to low-level File Descriptors that libmpv can consume.
     */
    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "openFileDescriptor" -> {
                val uriStr = call.argument<String>("uri")
                if (uriStr != null) {
                    try {
                        val uri = Uri.parse(uriStr)
                        // Opens the Content URI and returns a ParcelFileDescriptor.
                        val pfd = context.contentResolver.openFileDescriptor(uri, "r")
                        if (pfd != null) {
                            // Detaches the raw integer FD. Ownership is transferred to libmpv,
                            // which will be responsible for closing it after use.
                            val fd = pfd.detachFd()
                            result.success(fd)
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID", "uri is null", null)
                }
            }
            "closeFileDescriptor" -> {
                // Closes a raw FD previously detached in `openFileDescriptor`
                // when libmpv never consumed it (e.g. the load was aborted on
                // the Dart side after `_disposed` flipped). Without this the
                // descriptor leaks for the process lifetime.
                val fd = call.argument<Int>("fd")
                if (fd != null) {
                    try {
                        ParcelFileDescriptor.adoptFd(fd).close()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID", "fd is null", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Cleans up the plugin when detached from the engine.
     */
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        mediaSessionMethodChannel.setMethodCallHandler(null)
        mediaSessionEventChannel.setStreamHandler(null)
    }
}

/**
 * Stub handler for the OS media-session method + event channels.
 *
 * Logs every Dart→native call via android.util.Log and acks success
 * on the known method names. The actual MediaSessionCompat +
 * NotificationCompat.MediaStyle + foreground service + AudioFocus
 * integration lands in Phase 6. This stub exists so the Dart-side
 * MediaSessionController doesn't surface MissingPluginException on
 * Android builds while the native implementation is in flight.
 */
private class MediaSessionStubHandler :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        private const val TAG = "mpv_audio_kit/media_session"
    }

    private var eventSink: EventChannel.EventSink? = null

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.i(TAG, "stub call: ${call.method}")
        when (call.method) {
            "enable", "updateConfig", "updateMetadata", "updatePlayback", "disable" ->
                result.success(null)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        Log.i(TAG, "commands stream listener attached")
    }

    override fun onCancel(arguments: Any?) {
        Log.i(TAG, "commands stream listener cancelled")
        eventSink = null
    }
}
