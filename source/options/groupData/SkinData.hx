package options.groupData;

import options.objects.OptionCategory;
import options.Option;
import options.Option.OptionType;

class SkinData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Skin', 'Skin', 'specIcon');

        var notes:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
        var splashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt');
        var holdCovers:Array<String> = Mods.mergeAllTextsNamed('images/holdCover/list.txt');
        var ratings:Array<String> = Mods.mergeAllTextsNamed('images/ratings/list.txt');

        notes.insert(0, 'Default');
        splashes.insert(0, 'Psych');
        holdCovers.insert(0, 'Default');
        ratings.insert(0, 'Default');
        var sub = cat.section('Notes and Splashes', 'Note and Splashes');

        var openNoteColors = new Option('Note Colors', 'Customize note colors', '', ACTION);
        openNoteColors.actionLabel = 'Open';
        openNoteColors.action = function() {
            if (OptionsPageState.instance != null)
                OptionsPageState.instance.openSubState(new options.psychoptions.NotesColorSubState());
            else if (options.keoptions.KEOptionsMenu.instance != null)
                options.keoptions.KEOptionsMenu.instance.openSubState(new options.psychoptions.NotesColorSubState());
        };
        sub.add(openNoteColors);

        var openNoteHSV = new Option('Note HSV Colors', 'Customize legacy note HSV colors', '', ACTION);
        openNoteHSV.actionLabel = 'Open';
        openNoteHSV.action = function() {
            if (OptionsPageState.instance != null)
                OptionsPageState.instance.openSubState(new options.psychoptions.NotesHSVSubState());
            else if (options.keoptions.KEOptionsMenu.instance != null)
                options.keoptions.KEOptionsMenu.instance.openSubState(new options.psychoptions.NotesHSVSubState());
        };
        sub.add(openNoteHSV);


        sub.add(new Option('Note Skins', 'Select your preferred Note skin', 'noteSkin', STRING, notes));
        sub.add(new Option('Note Splashes', 'Select your preferred Note Splash variation', 'splashSkin', STRING, splashes));
        sub.add(new Option('Note HoldCover', 'Select your preferred Note Hold Cover', 'holdCoverSkin', STRING, holdCovers));

        var noteAlpha = new Option('Note Opacity', 'Note transparency', 'noteAlpha', FLOAT);
        noteAlpha.minValue = 0;
        noteAlpha.maxValue = 1;
        noteAlpha.changeValue = 0.1;
        noteAlpha.decimals = 2;
        sub.add(noteAlpha);

        var splashAlpha = new Option('Note Splash Opacity', 'Note splash transparency', 'splashAlpha', FLOAT);
        splashAlpha.minValue = 0;
        splashAlpha.maxValue = 1;
        splashAlpha.changeValue = 0.1;
        splashAlpha.decimals = 2;
        sub.add(splashAlpha);

        var holdcoverAlpha = new Option('Note HoldCover Opacity', 'Note hold cover transparency', 'holdcoverAlpha', FLOAT);
        holdcoverAlpha.minValue = 0;
        holdcoverAlpha.maxValue = 1;
        holdcoverAlpha.changeValue = 0.1;
        holdcoverAlpha.decimals = 2;
        sub.add(holdcoverAlpha);

        // 音符 / 溅射各自的三态体系开关（auto / legacy / new），互相独立：
        //   new  = 忽略谱面皮肤 + 强制 RGB；legacy = 沿用谱面皮肤 + 强制 HSV；auto = 引擎自己判
        sub.add(new Option('Note System', 'auto: detect | legacy: force HSV | new: force RGB + custom skin', 'noteSystem', STRING, ['auto', 'legacy', 'new']));
        sub.add(new Option('Splash System', 'auto: detect | legacy: force HSV | new: force RGB + custom skin', 'splashSystem', STRING, ['auto', 'legacy', 'new']));

        var sub = cat.section('Judgements', 'Judgements Settings');
        sub.add(new Option('Judgements Style', 'Select your preferred judgements Image', 'customUI', STRING, ratings));
        sub.add(new Option('Combo Stacking', 'Stack combo numbers', 'comboStacking', BOOL));
        sub.add(new Option('MS Number', 'Make you know how late/early ur when hit notes', 'showMS', BOOL));
        sub.add(new Option('Force Number Color', 'Force numbers to a specific color', 'forceNumberColor', BOOL));
        sub.add(new Option('showEarlyLate', 'Show early/late text on hit', 'showEarlyLate', BOOL));
        sub.add(new Option('showCombo', 'Show combo text when combo > 10', 'showCombo', BOOL));
        return cat;
    }
}