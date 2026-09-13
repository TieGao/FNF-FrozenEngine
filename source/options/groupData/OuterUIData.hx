package options.groupData;

import options.objects.OptionCategory;
import options.psychoptions.PsychOption;
import options.psychoptions.PsychOption.OptionType;

class OuterUIData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Outer UI', 'Outer UI Settings', 'specIcon');

        var sub = cat.section('Freeplay', 'Freeplay Settings');

        sub.add(new PsychOption('Old Freeplay Menu', 'Use Psych Engine Default Freeplay Menu', 'oldFreeplay', BOOL));
        sub.add(new PsychOption('Card Glow', 'Enable breathing glow under selected card', 'cardGlow', BOOL));
        sub.add(new PsychOption('Freeplay ToolBar', 'Show tool bar in freeplay', 'toolBar', BOOL));
        sub.add(new PsychOption('New Freeplay Space BackGround', 'Just a cool background lol', 'freeplayspace', BOOL));
        sub.add(new PsychOption('Save Freeplay Cache', 'Save freeplay song metadata cache to disk', 'saveFreeplayCache', BOOL));
        sub.add(new PsychOption('Space Back Ground EveryWhere', 'Show space background everywhere', 'globalspace', BOOL));
        sub.add(new PsychOption('Mod Folder Manager', 'Organize mods in Freeplay using folder selector', 'freeplayModFolder', BOOL));

        var relaxAudioNumber = new PsychOption('Audio Display Number', 'Change the relax audio number', 'relaxAudioNumber', INT);
        relaxAudioNumber.minValue = 1;
        relaxAudioNumber.maxValue = 64;
        relaxAudioNumber.changeValue = 1;
        sub.add(relaxAudioNumber);

        var relaxAudioDisplayQuality = new PsychOption('Audio Display Quality', 'Change the relax audio display quality', 'relaxAudioDisplayQuality', INT);
        relaxAudioDisplayQuality.minValue = 1;
        relaxAudioDisplayQuality.maxValue = 8;
        relaxAudioDisplayQuality.changeValue = 1;
        sub.add(relaxAudioDisplayQuality);

        var audioDisplayUpdate = new PsychOption('Audio Display Update Speed', 'Change the relax audio display update speed', 'audioDisplayUpdate', FLOAT);
        audioDisplayUpdate.minValue = 33;
        audioDisplayUpdate.maxValue = 100;
        audioDisplayUpdate.changeValue = 1;
        audioDisplayUpdate.decimals = 2;
        sub.add(audioDisplayUpdate);

        var audioGain = new PsychOption('Audio Gain', 'Change the relax audio range', 'audioGain', FLOAT);
        audioGain.minValue = 0.1;
        audioGain.maxValue = 10;
        audioGain.changeValue = 0.5;
        audioGain.decimals = 2;
        sub.add(audioGain);

        return cat;
    }
}