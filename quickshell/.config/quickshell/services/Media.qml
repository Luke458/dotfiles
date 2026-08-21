pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris

QtObject {
    id: root

    // Active player (filtered to exclude browsers for cleaner control)
    property var activePlayer: null
    
    // Metadata properties
    property var metadata: activePlayer && activePlayer.metadata ? activePlayer.metadata : null
    property string trackTitle: metadata ? (metadata["xesam:title"] || "") : ""
    property var artistArray: metadata ? metadata["xesam:artist"] : null
    // The spec says array-of-strings, but some players send a bare string.
    property string trackArtist: Array.isArray(artistArray) ? (artistArray[0] || "") : (artistArray || "")
    property string trackAlbum: metadata ? (metadata["xesam:album"] || "") : ""
    property string albumArtUrl: metadata ? (metadata["mpris:artUrl"] || "") : ""
    property real trackLength: metadata ? (metadata["mpris:length"] || 0) : 0
    
    // Playback state
    property real currentPosition: activePlayer ? activePlayer.position : 0
    property int playbackState: activePlayer ? activePlayer.playbackState : MprisPlaybackState.Stopped
    
    // Capabilities
    property bool canPlay: activePlayer ? activePlayer.canPlay : false
    property bool canPause: activePlayer ? activePlayer.canPause : false
    property bool canGoNext: activePlayer ? activePlayer.canGoNext : false
    property bool canGoPrevious: activePlayer ? activePlayer.canGoPrevious : false
    property bool canSeek: activePlayer ? activePlayer.canSeek : false

    property bool textHidden: false
    readonly property bool hasMedia: activePlayer !== null && trackTitle !== "" && playbackState !== MprisPlaybackState.Stopped

    onTrackTitleChanged: textHidden = false

    // Browser filter list
    readonly property var browserIdentities: ["firefox", "chrome", "chromium", "brave", "edge", "opera"]

    function playerTier(p) {
        const identity = (p.identity || "").toLowerCase();
        const isBrowser = browserIdentities.some(id => identity.includes(id));
        if (!isBrowser)
            return p.playbackState === MprisPlaybackState.Playing ? 0 : 1;
        return p.playbackState === MprisPlaybackState.Playing ? 2 : 3;
    }

    function updateActivePlayer() {
        const players = Mpris.players.values;
        if (players.length === 0) {
            activePlayer = null;
            return;
        }

        let best = null;
        let bestTier = 99;
        for (let i = 0; i < players.length; i++) {
            const tier = playerTier(players[i]);
            // Among equal-tier candidates prefer the incumbent so the UI does
            // not flip-flop between equivalent players on every state change.
            if (tier < bestTier || (tier === bestTier && players[i] === activePlayer)) {
                best = players[i];
                bestTier = tier;
            }
        }
        activePlayer = best;
    }

    function togglePlayPause() {
        if (!activePlayer) return;
        if (playbackState === MprisPlaybackState.Playing) {
            if (canPause) activePlayer.pause();
        } else if (canPlay) {
            activePlayer.play();
        }
    }

    function next() { if (activePlayer && canGoNext) activePlayer.next(); }
    function previous() { if (activePlayer && canGoPrevious) activePlayer.previous(); }
    
    function seek(ratio) {
        if (activePlayer && canSeek && trackLength > 0) {
            activePlayer.position = (ratio * trackLength) / 1e6;
        }
    }

    // Connect to global MPRIS player changes
    property Connections mprisConnections: Connections {
        target: Mpris.players
        function onValuesChanged() { root.updateActivePlayer(); }
    }

    property Instantiator playerConnections: Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData
            target: modelData

            function onPlaybackStateChanged() {
                root.updateActivePlayer();
            }

            function onPostTrackChanged() {
                root.updateActivePlayer();
                if (target === root.activePlayer)
                    target.positionChanged(); // qmllint disable missing-property
            }
        }
    }

    Component.onCompleted: updateActivePlayer()

    // MprisPlayer.position always returns the current value, but intentionally
    // does not notify continuously. Ask it to re-emit while playing instead of
    // writing currentPosition and breaking the binding above.
    property Timer positionTimer: Timer {
        interval: 250
        running: root.activePlayer && root.playbackState === MprisPlaybackState.Playing
        repeat: true
        // qmllint disable missing-property
        onTriggered: root.activePlayer.positionChanged() // qmllint disable missing-property
        // qmllint enable missing-property
    }
}
