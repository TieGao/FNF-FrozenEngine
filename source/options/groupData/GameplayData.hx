package options.groupData;

import options.objects.OptionCategory;
import options.Option;
import options.Option.OptionType;

class GameplayData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Gameplay', 'Gameplay', 'specIcon');
        var sub = cat.section('Gameplay', 'Gameplay Settings');
        sub.add(new Option('Downscroll', 'Notes scroll downwards instead of upwards', 'downScroll', BOOL));
        sub.add(new Option('Middlescroll', 'Put your lane in the center', 'middleScroll', BOOL));
        sub.add(new Option('Opponent Notes', 'Show opponent\'s strumline', 'opponentStrums', BOOL));
        sub.add(new Option('Ghost Tapping', 'Allow pressing keys without missing', 'ghostTapping', BOOL));
        sub.add(new Option('Auto Pause', 'Pause when window loses focus', 'autoPause', BOOL));
        sub.add(new Option('Disable Reset', 'Disable the reset button', 'noReset', BOOL));
        sub.add(new Option('Guitar Hero Sustains', 'Sustains count as one note', 'guitarHeroSustains', BOOL));
        sub.add(new Option('Fast Restart', 'Fast Restart When Dead or Press \'R\'', 'skipDeath', BOOL));

        var hitsoundVolume = new Option('Hitsound Volume', 'Volume of hit sounds', 'hitsoundVolume', FLOAT);
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
        sub.add(new Option('Hitsound', 'Choose the note hit sound', 'hitsound', STRING, hitsoundList));
        sub.add(new Option('Pause Music', 'Choose pause screen music', 'pauseMusic', STRING, ['None', 'Tea Time', 'Breakfast', 'Breakfast (Pico)']));

        var ratingOffset = new Option('Rating Offset', 'Adjust note hit timing', 'ratingOffset', INT);
        ratingOffset.minValue = -30;
        ratingOffset.maxValue = 30;
        ratingOffset.changeValue = 1;
        sub.add(ratingOffset);

        sub.add(new Option('Show Stage', 'Show the stage', 'showStage', BOOL));

        var noteSustainsOffset = new Option('Note Sustains Offset', 'Adjust the timing offset for note sustains', 'noteSustainsOffset', FLOAT);
        noteSustainsOffset.minValue = 0;
        noteSustainsOffset.maxValue = 1;
        noteSustainsOffset.changeValue = 0.05;
        noteSustainsOffset.decimals = 2;
        sub.add(noteSustainsOffset);

        sub.add(new Option('KE Style Sustains', 'Enable KE style note sustains', 'keLike', BOOL));

        var sub1 = cat.section('Window', 'Window Settings');

        var marvelousWindow = new Option('Marvelous Window', 'Timing window for SICK', 'marvelousWindow', FLOAT);
        marvelousWindow.minValue = 0;
        marvelousWindow.maxValue = 22.5;
        marvelousWindow.changeValue = 0.5;
        marvelousWindow.decimals = 2;
        sub1.add(marvelousWindow);

        var sickWindow = new Option('Sick Window', 'Timing window for SICK', 'sickWindow', FLOAT);
        sickWindow.minValue = 10;
        sickWindow.maxValue = 45;
        sickWindow.changeValue = 0.5;
        sickWindow.decimals = 2;
        sub1.add(sickWindow);

        var goodWindow = new Option('Good Window', 'Timing window for GOOD', 'goodWindow', FLOAT);
        goodWindow.minValue = 10;
        goodWindow.maxValue = 90;
        goodWindow.changeValue = 0.5;
        goodWindow.decimals = 2;
        sub1.add(goodWindow);

        var badWindow = new Option('Bad Window', 'Timing window for BAD', 'badWindow', FLOAT);
        badWindow.minValue = 10;
        badWindow.maxValue = 135;
        badWindow.changeValue = 0.5;
        badWindow.decimals = 2;
        sub1.add(badWindow);

        var safeFrames = new Option('Safe Frames', 'Frames for early/late hits', 'safeFrames', FLOAT);
        safeFrames.minValue = 2;
        safeFrames.maxValue = 10;
        safeFrames.changeValue = 1;
        safeFrames.decimals = 2;
        sub1.add(safeFrames);

        return cat;
    }
}