package options.groupData;

import options.objects.OptionCategory;
import options.psychoptions.PsychOption;
import options.psychoptions.PsychOption.OptionType;

class GameplayData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Gameplay', 'Gameplay', 'specIcon');
        var sub = cat.section('Gameplay', 'Gameplay Settings');
        sub.add(new PsychOption('Downscroll', 'Notes scroll downwards instead of upwards', 'downScroll', BOOL));
        sub.add(new PsychOption('Middlescroll', 'Put your lane in the center', 'middleScroll', BOOL));
        sub.add(new PsychOption('Opponent Notes', 'Show opponent\'s strumline', 'opponentStrums', BOOL));
        sub.add(new PsychOption('Ghost Tapping', 'Allow pressing keys without missing', 'ghostTapping', BOOL));
        sub.add(new PsychOption('Auto Pause', 'Pause when window loses focus', 'autoPause', BOOL));
        sub.add(new PsychOption('Disable Reset', 'Disable the reset button', 'noReset', BOOL));
        sub.add(new PsychOption('Guitar Hero Sustains', 'Sustains count as one note', 'guitarHeroSustains', BOOL));
        sub.add(new PsychOption('Fast Restart', 'Fast Restart When Dead or Press \'R\'', 'skipDeath', BOOL));

        var hitsoundVolume = new PsychOption('Hitsound Volume', 'Volume of hit sounds', 'hitsoundVolume', FLOAT);
        hitsoundVolume.minValue = 0;
        hitsoundVolume.maxValue = 1;
        hitsoundVolume.changeValue = 0.1;
        hitsoundVolume.decimals = 2;
        sub.add(hitsoundVolume);

        var hitsoundList:Array<String> = Mods.mergeAllTextsNamed('sounds/hitsounds/HitSound.txt');
        if (hitsoundList.length == 0) hitsoundList = ['hitsound'];
        for (i in 0...hitsoundList.length)
        {
            if (!hitsoundList[i].contains('/'))
                hitsoundList[i] = 'hitsounds/' + hitsoundList[i];
        }
        sub.add(new PsychOption('Hitsound', 'Choose the note hit sound', 'hitsound', STRING, hitsoundList));
        sub.add(new PsychOption('Pause Music', 'Choose pause screen music', 'pauseMusic', STRING, ['None', 'Tea Time', 'Breakfast', 'Breakfast (Pico)']));

        var ratingOffset = new PsychOption('Rating Offset', 'Adjust note hit timing', 'ratingOffset', INT);
        ratingOffset.minValue = -30;
        ratingOffset.maxValue = 30;
        ratingOffset.changeValue = 1;
        sub.add(ratingOffset);

        sub.add(new PsychOption('Show Stage', 'Show the stage', 'showStage', BOOL));

        var noteSustainsOffset = new PsychOption('Note Sustains Offset', 'Adjust the timing offset for note sustains', 'noteSustainsOffset', FLOAT);
        noteSustainsOffset.minValue = 0;
        noteSustainsOffset.maxValue = 1;
        noteSustainsOffset.changeValue = 0.05;
        noteSustainsOffset.decimals = 2;
        sub.add(noteSustainsOffset);

        sub.add(new PsychOption('KE Style Sustains', 'Enable KE style note sustains', 'keLike', BOOL));

        var sub1 = cat.section('Window', 'Window Settings');

        var marvelousWindow = new PsychOption('Marvelous Window', 'Timing window for SICK', 'marvelousWindow', FLOAT);
        marvelousWindow.minValue = 10;
        marvelousWindow.maxValue = 22.5;
        marvelousWindow.changeValue = 0.5;
        marvelousWindow.decimals = 2;
        sub1.add(marvelousWindow);

        var sickWindow = new PsychOption('Sick Window', 'Timing window for SICK', 'sickWindow', FLOAT);
        sickWindow.minValue = 10;
        sickWindow.maxValue = 45;
        sickWindow.changeValue = 0.5;
        sickWindow.decimals = 2;
        sub1.add(sickWindow);

        var goodWindow = new PsychOption('Good Window', 'Timing window for GOOD', 'goodWindow', FLOAT);
        goodWindow.minValue = 10;
        goodWindow.maxValue = 90;
        goodWindow.changeValue = 0.5;
        goodWindow.decimals = 2;
        sub1.add(goodWindow);

        var badWindow = new PsychOption('Bad Window', 'Timing window for BAD', 'badWindow', FLOAT);
        badWindow.minValue = 10;
        badWindow.maxValue = 135;
        badWindow.changeValue = 0.5;
        badWindow.decimals = 2;
        sub1.add(badWindow);

        var safeFrames = new PsychOption('Safe Frames', 'Frames for early/late hits', 'safeFrames', FLOAT);
        safeFrames.minValue = 2;
        safeFrames.maxValue = 10;
        safeFrames.changeValue = 1;
        safeFrames.decimals = 2;
        sub1.add(safeFrames);

        return cat;
    }
}