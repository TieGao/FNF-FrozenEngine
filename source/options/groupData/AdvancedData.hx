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
        sub.add(new Option('Disable GC While Playing', 'Disable hxcpp garbage collection during gameplay', 'disablePlayStateGC', BOOL));
        sub.add(new Option('Discord RPC', 'Enable Discord Rich Presence', 'discordRPC', BOOL));
        sub.add(new Option('Options Style', 'Choose which options menu style to use', 'optionstype', STRING, ['new', 'psych', 'ke']));
        sub.add(new Option('Use Default Mouse Cursor', 'Use ur system\'s default mouse cursor in game', 'useSystemCursor', BOOL));

        // 脚本诊断与日志输出单独一页。选项一律挂在自己的 section 上：用 cat.add 直挂主分类会
        // 多出一个排在最前的同名页（navPages() 把主分类自己也算一页），和已有的 'Advanced' 页重复。
        var dbg = cat.section('Debug', 'Debug');
        dbg.add(new Option('Enable LUA Debug Printer', 'Uncheck it if u dont want to see them', 'luadebugPrint', BOOL));
        dbg.add(new Option('Console Log On Screen', 'Show trace (console) output on screen, applies to every screen', 'screenLog', BOOL));

        var logLifetime = new Option('Console Log Lifetime', 'Seconds a trace line stays on screen before fading out', 'screenLogLifetime', INT);
        logLifetime.minValue = 1; logLifetime.maxValue = 30; logLifetime.decimals = 0;
        dbg.add(logLifetime);

        dbg.add(new Option('Save Session Log', 'Write trace output to crash/latest.log; the previous session is kept as crash/latest.1.log', 'sessionLog', BOOL));
        dbg.add(new Option('Blue Screen Crash Handler', 'Show a Windows-style blue screen when the game hits an uncaught error; off = native popup', 'blueScreen', BOOL));

        var bsDuration = new Option('Blue Screen Duration', 'Seconds before the blue screen returns to the title screen (0 = wait for a key)', 'blueScreenTime', INT);
        bsDuration.minValue = 0; bsDuration.maxValue = 60; bsDuration.decimals = 0;
        dbg.add(bsDuration);
        dbg.add(new Option('Lua Script Parser', 'Parse lua scripts before a song loads: native (off), check syntax only, or preload their assets', 'luaScriptParser', STRING, ['native', 'check', 'preload']));

        // 崩溃界面自测：故意制造一次空对象崩溃
        var crashTest = new Option('Crash Test', 'Triggers a null object crash on purpose. Do not click it for no reason!', '', ACTION);
        crashTest.actionLabel = 'Crash';
        crashTest.action = function() backend.BlueScreenCrashHandler.simulateNullCrash();
        dbg.add(crashTest);

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