const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuIconColor = "\\$8f9";
const string PluginIcon = "\\$s\\$o\\$i" + Icons::KeyboardO;
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

[Setting category="General" name="Intercept and block key presses when setting spectator." description="When enabled, the plugin will intercept and block key presses when setting a spectator target. This is useful to prevent the game from interpreting the key presses as other actions."]
bool S_InterceptKeyPresses = true;

[Setting category="General" name="Require holding Shift" description="When enabled, the plugin will only set a spectator target if the Shift key is held down."]
bool S_RequireShift = true;

UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    // check that we pressed a number key
    if (!down || int(key) < int(VirtualKey::N0) || int(key) > int(VirtualKey::N9))
        return UI::InputBlocking::DoNothing;
    if (S_RequireShift) {
        // and that we are holding shift
        bool shiftDown = UI::IsKeyDown(UI::Key::LeftShift) || UI::IsKeyDown(UI::Key::RightShift);
        if (!shiftDown)
            return UI::InputBlocking::DoNothing;
    }
    if (!IsInMapNotEditor())
        return UI::InputBlocking::DoNothing;
    int64 keyNumber = int(key) - int(VirtualKey::N0);
    startnew(RunChangeSpectator, keyNumber);
    return S_InterceptKeyPresses ? UI::InputBlocking::Block : UI::InputBlocking::DoNothing;
}

bool IsInMapNotEditor() {
    auto app = GetApp();
    return app.RootMap !is null && app.CurrentPlayground !is null && app.Editor is null;
}

bool IsInTeamsMode(CTrackManiaNetwork@ net) {
    string mode = cast<CTrackManiaNetworkServerInfo>(net.ServerInfo).CurGameModeStr;
    return mode.Contains("Teams");
}

int KeyNumToTeam(int64 keyNum) {
    if (1 <= keyNum && keyNum <= 5)
        return 1;
    return 2;
}

int KeyNumToPlayerIx(int keyNum, int team) {
    // transform 0 -> 10
    if (keyNum == 0) keyNum = 10;
    // if no teams, ix = keyNum - 1
    if (team < 0) return keyNum - 1;
    // team 1: map 1 -> 5 to 0 -> 4
    if (keyNum <= 5) return keyNum - 1;
    // team 2: map 6 -> 10 to 4 -> 0
    return 4 - (keyNum - 6);
}

void RunChangeSpectator(int64 keyNum) {
    if (keyNum > 9) return;
    auto app = GetApp();
    auto net = cast<CTrackManiaNetwork>(app.Network);
    if (!net.PlaygroundClientScriptAPI.IsSpectator)
        return;
    auto rd = MLFeed::GetRaceData_V4();
    bool hasTeams = IsInTeamsMode(net);
    int team = hasTeams ? KeyNumToTeam(keyNum) : -1;
    int playerIx = KeyNumToPlayerIx(keyNum, team);
    trace("Spectating team " + team + " player " + playerIx);
    auto player = GetPlayerFromRdOnTeam(rd, team, playerIx);
    if (player is null) return;
    net.PlaygroundClientScriptAPI.SetSpectateTarget(player.Login);
}

const MLFeed::PlayerCpInfo_V4@ GetPlayerFromRdOnTeam(const MLFeed::HookRaceStatsEventsBase_V4@ rd, int team, int playerIx) {
    auto @players = rd.SortedPlayers_Race_Respawns;
    int teamIx = 0;
    bool rightTeam;
    for (uint i = 0; i < players.Length; i++) {
        auto @player = cast<MLFeed::PlayerCpInfo_V4>(players[i]);
        rightTeam = team < 0 || team == player.TeamNum;
        if (!rightTeam) continue;
        if (teamIx == playerIx) return player;
        teamIx++;
    }
    return null;
}
