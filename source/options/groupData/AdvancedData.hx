package options.groupData;

import options.objects.OptionCategory;
import options.Option;
import options.Option.OptionType;

class AdvancedData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Advanced', 'Advanced', 'specIcon');

        var sub = cat.section('Advanced', 'Advanced Settings');
        sub.add(new Option('Check Updates', 'Check for game updates', 'checkForUpdates', BOOL));

        var maxSplashes = new Option('Max Note Splashes', 'Max note splashes shown per lane (0 or 100 = unlimited)', 'maxNoteSplashes', INT);
        maxSplashes.minValue = 0; maxSplashes.maxValue = 100; maxSplashes.decimals = 0;
        sub.add(maxSplashes);

        var maxPopups = new Option('Max Judgement Popups', 'Max judgement popups shown on screen (0 or 100 = unlimited)', 'maxJudgementPopups', INT);
        maxPopups.minValue = 0; maxPopups.maxValue = 100; maxPopups.decimals = 0;
        sub.add(maxPopups);

        sub.add(new Option('Beta Updates', 'Change the channel to beta', 'betaUpdates', BOOL));
        sub.add(new Option('Loading Screen', 'Show loading screen', 'loadingScreen', BOOL));
        sub.add(new Option('Lua Text Antialiasing', 'Enable antialiasing on lua texts', 'luatextantialiasing', BOOL));
        sub.add(new Option('Enable LUA Debug Printer', 'Uncheck it if u dont want to see them', 'luadebugPrint', BOOL));
        sub.add(new Option('Discord RPC', 'Enable Discord Rich Presence', 'discordRPC', BOOL));
        sub.add(new Option('Replay', '[Score Menu and Replay Required]', 'saveReplays', BOOL));
        sub.add(new Option('High Quality Replays', 'Enable high-quality replays', 'replayQuality', BOOL));
        sub.add(new Option('Options Style', 'Choose which options menu style to use', 'optionstype', STRING, ['new', 'psych', 'ke']));
        sub.add(new Option('Use Default Mouse Cursor', 'Use ur system\'s default mouse cursor in game', 'useSystemCursor', BOOL));

        var about = new Option('About', 'View information about the game', '', ACTION);
        about.actionLabel = 'Open';
        about.action = function() {
            if (OptionsPageState.instance != null)
                OptionsPageState.instance.openSubState(new substates.AboutSubState());
            else if (options.keoptions.KEOptionsMenu.instance != null)
                options.keoptions.KEOptionsMenu.instance.openSubState(new substates.AboutSubState());
        };
        sub.add(about);

        var resetSettings = new Option('Reset Settings', 'Reset all settings to default', 'settings', ACTION);
        resetSettings.actionLabel = 'Reset';
        resetSettings.action = function() {
            ClientPrefs.data = ClientPrefs.defaultData;
            ClientPrefs.saveSettings();
            ClientPrefs.loadPrefs();
        };
        sub.add(resetSettings);

        return cat;
    }
}