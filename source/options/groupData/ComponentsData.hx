package options.groupData;

import options.objects.OptionCategory;
import options.Option;
import options.Option.OptionType;

class ComponentsData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Components', 'Components', 'specIcon');

        var sub1 = cat.section('HitErrorBar', 'Hit Error Bar');
        sub1.add(new Option('Hit Error Bar', 'Show hit error bar', 'hitErrorBarVisible', BOOL));
        sub1.add(new Option('Hit Error Bar Pointer Style', 'Style of the hit error bar pointer', 'pointerType', STRING, ['triangle', 'inverted', 'thick_line']));

        var hitBarLines = new Option('Hit Bar Lines', 'Number of lines on hit error bar', 'hitBarLines', INT);
        hitBarLines.minValue = 0;
        hitBarLines.maxValue = 200;
        hitBarLines.changeValue = 1;
        sub1.add(hitBarLines);

        var hitBarLineTime = new Option('Hit Bar Line Time', 'Time (in seconds) each line represents', 'hitBarLineTime', FLOAT);
        hitBarLineTime.minValue = 0.1;
        hitBarLineTime.maxValue = 5;
        hitBarLineTime.changeValue = 0.1;
        hitBarLineTime.decimals = 2;
        sub1.add(hitBarLineTime);

        var hitErrorBarOffsetX = new Option('Hit Error Bar Offset X', 'Horizontal position of hit error bar', 'hitErrorBarOffsetX', INT);
        hitErrorBarOffsetX.minValue = -500;
        hitErrorBarOffsetX.maxValue = 500;
        hitErrorBarOffsetX.changeValue = 1;
        sub1.add(hitErrorBarOffsetX);

        var hitErrorBarOffsetY = new Option('Hit Error Bar Offset Y', 'Vertical position of hit error bar', 'hitErrorBarOffsetY', INT);
        hitErrorBarOffsetY.minValue = -300;
        hitErrorBarOffsetY.maxValue = 300;
        hitErrorBarOffsetY.changeValue = 1;
        sub1.add(hitErrorBarOffsetY);

        sub1.add(new Option('Hit Error Bar MS', 'Show MS on hit error bar rather than on ratings', 'msInErrorBar', BOOL));

        var sub2 = cat.section('KeyboardDisplay', 'Keyboard Display');
        sub2.add(new Option('Show Keyboard', 'Display keyboard on screen', 'kb', BOOL));

        var keyboardAlpha = new Option('Keyboard Opacity', 'Transparency of the keyboard display', 'keyboardAlpha', FLOAT);
        keyboardAlpha.minValue = 0;
        keyboardAlpha.maxValue = 1;
        keyboardAlpha.changeValue = 0.1;
        keyboardAlpha.decimals = 2;
        sub2.add(keyboardAlpha);

        var kbOffsetX = new Option('Keyboard Offset X', 'Horizontal position of the keyboard display', 'kbOffsetX', INT);
        kbOffsetX.minValue = -750;
        kbOffsetX.maxValue = 750;
        kbOffsetX.changeValue = 1;
        sub2.add(kbOffsetX);

        var kbOffsetY = new Option('Keyboard Offset Y', 'Vertical position of the keyboard display', 'kbOffsetY', INT);
        kbOffsetY.minValue = -450;
        kbOffsetY.maxValue = 750;
        kbOffsetY.changeValue = 1;
        sub2.add(kbOffsetY);

        sub2.add(new Option('Keyboard Time Display', 'Change the keyboard time should display or not', 'keyboardTimeDisplay', BOOL));

        var keyboardTime = new Option('Keyboard Time Length', 'Change the how long the keyboard is displayed', 'keyboardTime', FLOAT);
        keyboardTime.minValue = 0;
        keyboardTime.maxValue = 2000;
        keyboardTime.changeValue = 20;
        keyboardTime.decimals = 2;
        sub2.add(keyboardTime);

        sub2.add(new Option('Keyboard BG Color', 'Background color of the keyboard display', 'keyboardBGColor', COLOR));
        sub2.add(new Option('Keyboard Text Color', 'Text color of the keyboard display', 'keyboardTextColor', COLOR));

        
        var sub3 = cat.section('JudgementsCounter', 'Judgements Counter');
        sub3.add(new Option('Judgements Counter', 'Show judgements counter', 'Counter', BOOL));
        sub3.add(new Option('Show Highest Combo', 'Show highest combo in judgements counter', 'showHC', BOOL));
        sub3.add(new Option('Show Current Combo', 'Show current combo in judgements counter', 'showCB', BOOL));
        sub3.add(new Option('Show Total Notes Hit', 'Show total notes hit in judgements counter', 'showTNH', BOOL));
        sub3.add(new Option('Show Misses', 'Show misses in judgements counter', 'showMiss', BOOL));

        var sub4 = cat.section('SongInfoText', 'Song Info Text');
        sub4.add(new Option('Song Info Text', 'Show Song Info Text', 'songText', BOOL));
        sub4.add(new Option('Show Difficulty', 'Show difficulty in song info text', 'showDifficulty', BOOL));
        sub4.add(new Option('Song Engine Version', 'Show engine version in song info text', 'showEngineVer', BOOL));

        var songInfoTextSize = new Option('Song Info Text Size', 'Change the size of song info text', 'songInfoTextSize', FLOAT);
        songInfoTextSize.minValue = 0.5;
        songInfoTextSize.maxValue = 3.0;
        songInfoTextSize.changeValue = 0.1;
        songInfoTextSize.decimals = 2;
        sub4.add(songInfoTextSize);

        var sub5 = cat.section('ChartHelper', 'Chart Helper');

        var guideLineAlpha = new Option('Note Guide Line Opacity', 'Transparency of the chart helper display', 'guideLineAlpha', FLOAT);
        guideLineAlpha.minValue = 0;
        guideLineAlpha.maxValue = 1;
        guideLineAlpha.changeValue = 0.1;
        guideLineAlpha.decimals = 2;
        sub5.add(guideLineAlpha);



        return cat;
    }
}