package options.groupData;

import options.objects.OptionCategory;
import options.psychoptions.PsychOption;
import options.psychoptions.PsychOption.OptionType;

class SkinData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Skin', 'Skin', 'specIcon');

        var notes:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
        var splashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt');
        var holdCovers:Array<String> = Mods.mergeAllTextsNamed('images/holdCover/list.txt');
        var ratings:Array<String> = Mods.mergeAllTextsNamed('images/ratings/list.txt');

        if (notes.length == 0) notes = ['Default'];
        if (splashes.length == 0) splashes = ['Psych'];
        if (holdCovers.length == 0) holdCovers = ['Default'];
        if (ratings.length == 0) ratings = ['Default'];
        var sub = cat.section('Notes and Splashes', 'Note and Splashes');

        var openNoteColors = new PsychOption('Note Colors', 'Customize note colors', '', ACTION);
        openNoteColors.actionLabel = 'Open';
        openNoteColors.action = function() {
            if (OptionsPageState.instance != null)
                OptionsPageState.instance.openSubState(new options.psychoptions.NotesColorSubState());
            else if (options.keoptions.KEOptionsMenu.instance != null)
                options.keoptions.KEOptionsMenu.instance.openSubState(new options.psychoptions.NotesColorSubState());
        };
        sub.add(openNoteColors);


        sub.add(new PsychOption('Note Skins', 'Select your preferred Note skin', 'noteSkin', STRING, notes));
        sub.add(new PsychOption('Note Splashes', 'Select your preferred Note Splash variation', 'splashSkin', STRING, splashes));
        sub.add(new PsychOption('Note HoldCover', 'Select your preferred Note Hold Cover', 'holdCoverSkin', STRING, holdCovers));

        var noteAlpha = new PsychOption('Note Opacity', 'Note transparency', 'noteAlpha', FLOAT);
        noteAlpha.minValue = 0;
        noteAlpha.maxValue = 1;
        noteAlpha.changeValue = 0.1;
        noteAlpha.decimals = 2;
        sub.add(noteAlpha);

        var splashAlpha = new PsychOption('Note Splash Opacity', 'Note splash transparency', 'splashAlpha', FLOAT);
        splashAlpha.minValue = 0;
        splashAlpha.maxValue = 1;
        splashAlpha.changeValue = 0.1;
        splashAlpha.decimals = 2;
        sub.add(splashAlpha);

        var holdcoverAlpha = new PsychOption('Note HoldCover Opacity', 'Note hold cover transparency', 'holdcoverAlpha', FLOAT);
        holdcoverAlpha.minValue = 0;
        holdcoverAlpha.maxValue = 1;
        holdcoverAlpha.changeValue = 0.1;
        holdcoverAlpha.decimals = 2;
        sub.add(holdcoverAlpha);

        sub.add(new PsychOption('Force Note Skin', 'Force using the custom note skin', 'forceNoteSkin', BOOL));
        sub.add(new PsychOption('Force Splash Skin', 'Force using the custom splash skin', 'forceSplashSkin', BOOL));
        sub.add(new PsychOption('Force RGB Shader', 'Force using the RGB shader for notes and splashes', 'forceRGBShader', BOOL));

        var sub = cat.section('Judgements', 'Judgements Settings');
        sub.add(new PsychOption('Judgements Style', 'Select your preferred judgements Image', 'customUI', STRING, ratings));
        sub.add(new PsychOption('Combo Stacking', 'Stack combo numbers', 'comboStacking', BOOL));
        sub.add(new PsychOption('MS Number', 'Make you know how late/early ur when hit notes', 'showMS', BOOL));
        sub.add(new PsychOption('Force Number Color', 'Force numbers to a specific color', 'forceNumberColor', BOOL));
        sub.add(new PsychOption('showEarlyLate', 'Show early/late text on hit', 'showEarlyLate', BOOL));
        sub.add(new PsychOption('showCombo', 'Show combo text when combo > 10', 'showCombo', BOOL));
        return cat;
    }
}