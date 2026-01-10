import asyncio
from ignis import widgets
from ignis.services.mpris import MprisService, MprisPlayer
from ignis import utils

mpris = MprisService.get_default()

class Music(widgets.Box):
    def __init__(self):
        super().__init__(
            css_classes=["music-widget", "unset"],
            visible=False,
        )
        self._player = None
        self._observed_players = set()
        
        self._label = widgets.Label(
            label="No Media",
            css_classes=["music-label"],
            ellipsize="end",
            max_width_chars=40,
        )
        
        self._box = widgets.Box(
            child=[
                self._label,
            ],
            spacing=10,
        )
        self.append(self._box)
        
        # Connect to mpris service
        mpris.connect("player_added", self.__on_player_added)
        
        # Observe all current players
        for p in mpris.players:
            self.__observe_player(p)
            
        # Initial scan
        self.__rescan_players()

    def __observe_player(self, player):
        if player in self._observed_players:
            return
            
        try:
            player.connect("notify::playback-status", self.__on_playback_status_changed)
            player.connect("closed", self.__on_player_closed)
            self._observed_players.add(player)
        except Exception as e:
            print(f"Failed to observe player: {e}")

    def __rescan_players(self):
        players = mpris.players
        
        # Priority: Playing > Paused > Stopped
        # Secondary: First in list
        
        candidate = None
        
        # Look for playing
        for p in players:
            # print(f"DEBUG: Player {p.name} status: {p.playback_status}")
            if p.playback_status == "Playing":
                candidate = p
                break
        
        # If no playing, just take first available
        if not candidate and players:
            candidate = players[0]
            
        if candidate:
            if self._player != candidate:
                self.__set_player(candidate)
        else:
            self._player = None
            self.visible = False

    def __on_player_added(self, service, player):
        self.__observe_player(player)
        self.__rescan_players()

    def __on_playback_status_changed(self, player, *args):
        # If a player starts playing, switch to it
        if player.playback_status == "Playing":
            if self._player != player:
                self.__set_player(player)
        elif self._player == player and player.playback_status != "Playing":
            # Current player stopped playing.
            # Check if anyone else is playing?
            # Or just stay on this one until someone else starts?
            # Let's rescan to be safe, maybe another one started.
            self.__rescan_players()

    def __on_player_closed(self, player):
        if player in self._observed_players:
            self._observed_players.remove(player)
            
        if self._player == player:
            self._player = None
            self.__rescan_players()

    def __set_player(self, player):
        self._player = player
        self.visible = True
        
        # Connect signals for title/artist updates
        # We can re-connect safely because these are specific to the "active" player visualization
        player.connect("notify::title", lambda x, y: self.__update_label(x))
        player.connect("notify::artist", lambda x, y: self.__update_label(x))
        self.__update_label(player)

    def __update_label(self, player):
        if player != self._player:
            return
            
        title = player.title
        artist = player.artist
        
        text = ""
        if title:
            text = title
            if artist:
                text = f"{artist} - {text}"
        elif artist:
            text = artist
        else:
            text = "Unknown"
            
        self._label.label = text
