package options.groupData;

import options.objects.OptionCategory;
import options.psychoptions.PsychOption;
import options.psychoptions.PsychOption.OptionType;

class AdvancedData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Advanced', 'Advanced', 'specIcon');

        var sub = cat.section('Advanced', 'Advanced Settings');
        sub.add(new PsychOption('Check Updates', 'Check for game updates', 'checkForUpdates', BOOL));
        sub.add(new PsychOption('Beta Updates', 'Change the channel to beta', 'betaUpdates', BOOL));
        sub.add(new PsychOption('Loading Screen', 'Show loading screen', 'loadingScreen', BOOL));
        sub.add(new PsychOption('Lua Text Antialiasing', 'Enable antialiasing on lua texts', 'luatextantialiasing', BOOL));
        sub.add(new PsychOption('Enable LUA Debug Printer', 'Uncheck it if u dont want to see them', 'luadebugPrint', BOOL));
        sub.add(new PsychOption('Discord RPC', 'Enable Discord Rich Presence', 'discordRPC', BOOL));
        sub.add(new PsychOption('Replay', '[Score Menu and Replay Required]', 'saveReplays', BOOL));
        sub.add(new PsychOption('Legacy Replay', 'Use the legacy note-based replay system', 'legacyReplay', BOOL));
        sub.add(new PsychOption('High Quality Replays', 'Enable high-quality replays', 'replayQuality', BOOL));
        sub.add(new PsychOption('Options Style', 'Choose which options menu style to use', 'optionstype', STRING, ['new', 'psych', 'ke']));
        sub.add(new PsychOption('Use Default Mouse Cursor', 'Use ur system\'s default mouse cursor in game', 'useSystemCursor', BOOL));

        var about = new PsychOption('About', 'View information about the game', '', ACTION);
        about.actionLabel = 'Open';
        about.action = function() {
            if (OptionsPageState.instance != null)
                OptionsPageState.instance.openSubState(new substates.AboutSubState());
            else if (options.keoptions.KEOptionsMenu.instance != null)
                options.keoptions.KEOptionsMenu.instance.openSubState(new substates.AboutSubState());
        };
        sub.add(about);

        var resetSettings = new PsychOption('Reset Settings', 'Reset all settings to default', 'settings', ACTION);
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