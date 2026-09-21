package options.groupData;

import options.objects.OptionCategory;
import options.Option;
import options.Option.OptionType;

class BasicsData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Basics', 'Basics', 'specIcon');

        var openControls = new Option('Open Controls', 'Customize key bindings', '', ACTION);
        openControls.actionLabel = 'Open';
        openControls.action = function() {
            if (OptionsPageState.instance != null)
                OptionsPageState.instance.openSubState(new options.psychoptions.ControlsSubState());
            else if (options.keoptions.KEOptionsMenu.instance != null)
                options.keoptions.KEOptionsMenu.instance.openSubState(new options.psychoptions.ControlsSubState());
        };
        cat.add(openControls);

        var openEKControls = new Option('Open EK Controls', 'Customize key bindings for EK mode', '', ACTION);
        openEKControls.actionLabel = 'Open';
        openEKControls.action = function() {
            if (OptionsPageState.instance != null)
                OptionsPageState.instance.openSubState(new options.psychoptions.ExtraKeybindSubState());
            else if (options.keoptions.KEOptionsMenu.instance != null)
                options.keoptions.KEOptionsMenu.instance.openSubState(new options.psychoptions.ExtraKeybindSubState());
        };
        cat.add(openEKControls);

        var adjustDelay = new Option('Adjust Delay and Combo', 'Customize ingame experience', '', ACTION);
        adjustDelay.actionLabel = 'Open';
        adjustDelay.action = function() {
            MusicBeatState.switchState(new options.psychoptions.NoteOffsetState());
        };
        cat.add(adjustDelay);

        cat.add(new Option('Language', 'Change the game\'s language', 'language', STRING, ['en-US', 'pt-BR', 'zh-CN', 'zh-TW']));
        cat.add(new Option('Color Mode', 'Switch between dark and white mode', 'colorMode', STRING, ['dark', 'white']));
        cat.add(new Option('Control Theme', 'Choose the button style: auto (each UI uses its own style), win10 or win8',
            'controlTheme', STRING, ['auto', 'win10', 'win8']));

        var resetKeyBinds = new Option('Reset KeyBinds', 'Reset key bindings', 'keybinds', ACTION);
        resetKeyBinds.actionLabel = 'Reset';
        resetKeyBinds.action = function() {
            ClientPrefs.resetKeys();
            ClientPrefs.saveSettings();
        };
        cat.add(resetKeyBinds);

        return cat;
    }
}