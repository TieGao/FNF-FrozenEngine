package options.groupData;

import options.objects.OptionCategory;
import options.Option;
import options.Option.OptionType;

class OuterUIData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Outer UI', 'Outer UI Settings', 'specIcon');

        var sub = cat.section('Freeplay', 'Freeplay Settings');

        sub.add(new Option('Old Freeplay Menu', 'Use Psych Engine Default Freeplay Menu', 'oldFreeplay', BOOL));
        sub.add(new Option('Card Glow', 'Enable breathing glow under selected card', 'cardGlow', BOOL));
        sub.add(new Option('Freeplay ToolBar', 'Show tool bar in freeplay', 'toolBar', BOOL));
        sub.add(new Option('New Freeplay Space BackGround', 'Just a cool background lol', 'freeplayspace', BOOL));
        sub.add(new Option('Save Freeplay Cache', 'Save freeplay song metadata cache to disk', 'saveFreeplayCache', BOOL));
        sub.add(new Option('Space Back Ground EveryWhere', 'Show space background everywhere', 'globalspace', BOOL));
        sub.add(new Option('Mod Folder Manager', 'Organize mods in Freeplay using folder selector', 'freeplayModFolder', BOOL));

        var relaxAudioNumber = new Option('Audio Display Number', 'Change the relax audio number', 'relaxAudioNumber', INT);
        relaxAudioNumber.minValue = 1;
        relaxAudioNumber.maxValue = 64;
        relaxAudioNumber.changeValue = 1;
        sub.add(relaxAudioNumber);

        var relaxAudioDisplayQuality = new Option('Audio Display Quality', 'Change the relax audio display quality', 'relaxAudioDisplayQuality', INT);
        relaxAudioDisplayQuality.minValue = 1;
        relaxAudioDisplayQuality.maxValue = 8;
        relaxAudioDisplayQuality.changeValue = 1;
        sub.add(relaxAudioDisplayQuality);

        var audioDisplayUpdate = new Option('Audio Display Update Speed', 'Change the relax audio display update speed', 'audioDisplayUpdate', FLOAT);
        audioDisplayUpdate.minValue = 33;
        audioDisplayUpdate.maxValue = 100;
        audioDisplayUpdate.changeValue = 1;
        audioDisplayUpdate.decimals = 2;
        sub.add(audioDisplayUpdate);

        var audioGain = new Option('Audio Gain', 'Change the relax audio range', 'audioGain', FLOAT);
        audioGain.minValue = 0.1;
        audioGain.maxValue = 10;
        audioGain.changeValue = 0.5;
        audioGain.decimals = 2;
        sub.add(audioGain);

        return cat;
    }
}