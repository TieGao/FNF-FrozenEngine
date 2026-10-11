package options.groupData;

import options.objects.OptionCategory;
import options.Option;
import options.Option.OptionType;

class GameUIData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('GameUI', 'In-Game UI', 'specIcon');

        var sub = cat.section('GameUI', 'In-Game UI');
        sub.add(new Option('Hide HUD', 'Hide most HUD elements', 'hideHud', BOOL));
        sub.add(new Option('Show Stage', 'Show the stage', 'showStage', BOOL));
        sub.add(new Option('In-Game Font Follows Language',
            'HUD and Lua/HScript text use the language font',
            'gameFontFollowLanguage', BOOL, null, 'game_font_follow_language'));
        sub.add(new Option('Flashing Lights', 'Enable screen flashes', 'flashing', BOOL));
        sub.add(new Option('Camera Zooms', 'Zoom camera on beat', 'camZooms', BOOL));
        sub.add(new Option('Custom Color', 'Color most things by opponent', 'customColor', BOOL));
        sub.add(new Option('Gradient TimeBar', 'Gradient colored timebar', 'gradientTimeBar', BOOL));
        sub.add(new Option('Score Zoom', 'Grow score text on hit', 'scoreZoom', BOOL));
        sub.add(new Option('Time Bar', 'What should the Time Bar display?', 'timeBarType', STRING, ['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']));

        var healthBarAlpha = new Option('Health Bar Alpha', 'Health bar transparency', 'healthBarAlpha', PERCENT);
        healthBarAlpha.minValue = 0;
        healthBarAlpha.maxValue = 1;
        healthBarAlpha.changeValue = 0.01;
        healthBarAlpha.decimals = 2;
        sub.add(healthBarAlpha);

        sub.add(new Option('Health Text', 'Show health as number', 'healthText', BOOL));
        

        // 暂停菜单相关设置统一放这一页：外观/布局、音乐，再到动画与输入。
        // id 不能和父分类的 'GameUI' 重复，否则页头标题会印两遍。
        // 显式传 translation，避免以后改显示名把译文弄丢。
        var pause = cat.section('PauseMenu', 'Pause Menu');
        pause.add(new Option('Charm Bar Pause', 'Modern Pause Sub State', 'charmPause', BOOL));
        pause.add(new Option('Center Pause', 'Center pause menu', 'centerPause', BOOL));
        pause.add(new Option('Pause Music', 'Choose pause screen music', 'pauseMusic', STRING, ['None', 'Tea Time', 'Breakfast', 'Breakfast (Pico)']));
        pause.add(new Option('Skip Pause Fade In', 'Skip the pause menu intro animation', 'pauseSkipFadeIn', BOOL, null, 'pause_skip_fade_in'));
        pause.add(new Option('Skip Pause Fade Out', 'Skip the pause menu closing animation', 'pauseSkipFadeOut', BOOL, null, 'pause_skip_fade_out'));
        pause.add(new Option('Double Enter to Skip', 'Press Enter twice while the pause menu is closing to skip the animation', 'pauseDoubleEnterSkip', BOOL, null, 'pause_double_enter_skip'));
        pause.add(new Option('Control During Animation', 'Allow using the pause menu while the intro animation is still playing', 'pauseUnlockInputDuringAnim', BOOL, null, 'pause_unlock_input'));

        return cat;
    }
}