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
        sub.add(new Option('Flashing Lights', 'Enable screen flashes', 'flashing', BOOL));
        sub.add(new Option('Camera Zooms', 'Zoom camera on beat', 'camZooms', BOOL));
        sub.add(new Option('Center Pause', 'Center pause menu', 'centerPause', BOOL));
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
        sub.add(new Option('Score Screen', 'Show Kade-style results', 'scoreScreen', BOOL));
        sub.add(new Option('Transition Type', 'Choose the transition animation style when switching scenes', 'transitionType', STRING, ['fade', 'pixel', 'loading']));
        sub.add(new Option('Blur Effect', 'Enable blur effect on background elements', 'blurEffects', BOOL));
        sub.add(new Option('Skip Results Screen Fade Out', 'Skip the exit results screen animation', 'skipResultExitAnim', BOOL));
        sub.add(new Option('Charm Bar Pause', 'Modern Pause Sub State', 'charmPause', BOOL));

        return cat;
    }
}