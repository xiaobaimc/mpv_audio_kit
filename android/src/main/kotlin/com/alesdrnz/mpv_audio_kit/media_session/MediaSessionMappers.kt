/*
 * Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.
 */
package com.alesdrnz.mpv_audio_kit.media_session

import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi

/**
 * Pure, stateless translation between the Dart wire contract and the
 * *public* Media3 types. Anything touching `SimpleBasePlayer`'s protected
 * surface (`MediaItemData`, `getState`, `invalidateState`) must live
 * inside [MpvControllerPlayer] instead — that's why playlist construction
 * is there, not here.
 */
@UnstableApi
internal object MediaSessionMappers {

    /** Wire loop string → Media3 repeat-mode constant. */
    fun loopToRepeatMode(loop: String): Int = when (loop) {
        "file" -> Player.REPEAT_MODE_ONE
        "playlist" -> Player.REPEAT_MODE_ALL
        else -> Player.REPEAT_MODE_OFF
    }

    /** Media3 repeat-mode constant → wire loop string. */
    fun repeatModeToLoop(repeatMode: Int): String = when (repeatMode) {
        Player.REPEAT_MODE_ONE -> "file"
        Player.REPEAT_MODE_ALL -> "playlist"
        else -> "off"
    }

    /**
     * Builds the command set advertised to the OS from the Dart [actions]
     * set, gated on [seekable] for the scrubber. The OS shows only the
     * buttons it has UI space for, but offers the wider set to Auto /
     * Assistant. The `GET_*` reads let controllers (System UI, Auto) read
     * timeline + metadata.
     */
    fun buildCommands(actions: Set<String>, seekable: Boolean): Player.Commands {
        val b = Player.Commands.Builder()
        b.add(Player.COMMAND_GET_CURRENT_MEDIA_ITEM)
        b.add(Player.COMMAND_GET_TIMELINE)
        b.add(Player.COMMAND_GET_METADATA)
        // Must be advertised or SimpleBasePlayer.release() early-returns
        // without tearing down listeners (leaks across enable/disable cycles).
        b.add(Player.COMMAND_RELEASE)
        if ("play" in actions || "pause" in actions || "playPause" in actions) {
            b.add(Player.COMMAND_PLAY_PAUSE)
        }
        if ("stop" in actions) b.add(Player.COMMAND_STOP)
        if ("seek" in actions && seekable) {
            b.add(Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM)
            b.add(Player.COMMAND_SEEK_TO_DEFAULT_POSITION)
        }
        if ("next" in actions) b.add(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
        if ("previous" in actions) b.add(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
        if ("fastForward" in actions) b.add(Player.COMMAND_SEEK_FORWARD)
        if ("rewind" in actions) b.add(Player.COMMAND_SEEK_BACK)
        if ("setRepeatMode" in actions) b.add(Player.COMMAND_SET_REPEAT_MODE)
        if ("setShuffle" in actions) b.add(Player.COMMAND_SET_SHUFFLE_MODE)
        if ("setPlaybackRate" in actions) b.add(Player.COMMAND_SET_SPEED_AND_PITCH)
        return b.build()
    }

    /** Resolved metadata snapshot → Media3 [MediaMetadata]. */
    fun toMediaMetadata(meta: MediaSessionManager.MetadataSnapshot): MediaMetadata {
        val b = MediaMetadata.Builder()
        meta.title?.let { b.setTitle(it) }
        meta.artist?.let { b.setArtist(it) }
        meta.album?.let { b.setAlbumTitle(it) }
        // Media3 takes raw encoded image bytes (JPEG/PNG) directly and
        // decodes them for the notification — no Bitmap conversion needed.
        meta.artworkBytes?.let {
            b.setArtworkData(it, MediaMetadata.PICTURE_TYPE_FRONT_COVER)
        }
        return b.build()
    }
}
