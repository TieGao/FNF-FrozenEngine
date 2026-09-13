package options.groupData;

import options.objects.OptionCategory;
import options.psychoptions.PsychOption;
import options.psychoptions.PsychOption.OptionType;

class GameUIData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('GameUI', 'In-Game UI', 'specIcon');

        var sub = cat.section('GameUI', 'In-Game UI');
        sub.add(new PsychOption('Hide HUD', 'Hide most HUD elements', 'hideHud', BOOL));
        sub.add(new PsychOption('Flashing Lights', 'Enable screen flashes', 'flashing', BOOL));
        sub.add(new PsychOption('Camera Zooms', 'Zoom camera on beat', 'camZooms', BOOL));
        sub.add(new PsychOption('Center Pause', 'Center pause menu', 'centerPause', BOOL));
        sub.add(new PsychOption('Custom Color', 'Color most things by opponent', 'customColor', BOOL));
        sub.add(new PsychOption('Gradient TimeBar', 'Gradient colored timebar', 'gradientTimeBar', BOOL));
        sub.add(new PsychOption('Score Zoom', 'Grow score text on hit', 'scoreZoom', BOOL));
        sub.add(new PsychOption('Time Bar', 'What should the Time Bar display?', 'timeBarType', STRING, ['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']));

        var healthBarAlpha = new PsychOption('Health Bar Alpha', 'Health bar transparency', 'healthBarAlpha', PERCENT);
        healthBarAlpha.minValue = 0;
        healthBarAlpha.maxValue = 1;
        healthBarAlpha.changeValue = 0.01;
        healthBarAlpha.decimals = 2;
        sub.add(healthBarAlpha);

        sub.add(new PsychOption('Health Text', 'Show health as number', 'healthText', BOOL));
        sub.add(new PsychOption('Score Screen', 'Show Kade-style results', 'scoreScreen', BOOL));
        sub.add(new PsychOption('Transition Type', 'Choose the transition animation style when switching scenes', 'transitionType', STRING, ['fade', 'pixel', 'loading']));
        sub.add(new PsychOption('Blur Effect', 'Enable blur effect on background elements', 'blurEffects', BOOL));
        sub.add(new PsychOption('Skip Results Screen Fade Out', 'Skip the exit results screen animation', 'skipResultExitAnim', BOOL));
        sub.add(new PsychOption('Charm Bar Pause', 'Modern Pause Sub State', 'charmPause', BOOL));

        return cat;
    }
}