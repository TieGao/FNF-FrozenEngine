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
        sub.add(new Option('Difficulty Stars', 'Show the official star rating above the album cover', 'freeplayStars', BOOL));
        sub.add(new Option('Album Cover', 'Show the album cover on the right side of Freeplay', 'freeplayAlbumArt', BOOL));
        sub.add(new Option('Difficulty Blocks', 'Show the clickable difficulty blocks in Freeplay', 'freeplayDiffCarousel', BOOL));
        sub.add(new Option('Freeplay ToolBar', 'Show tool bar in freeplay', 'toolBar', BOOL));
        sub.add(new Option('New Freeplay Space BackGround', 'Just a cool background lol', 'freeplayspace', BOOL));
        sub.add(new Option('Background Transition', 'How the Freeplay background switches when you change mod folder',
            'freeplayBgTransition', STRING, ['fade', 'mosaic']));
        sub.add(new Option('Save Freeplay Cache', 'Save freeplay song metadata cache to disk', 'saveFreeplayCache', BOOL));
        sub.add(new Option('Threaded Song Conversion', 'Parse chart info on a background thread (turn off if Freeplay stutters)', 'freeplayThreadedParse', BOOL));
        sub.add(new Option('Space Back Ground EveryWhere', 'Show space background everywhere', 'globalspace', BOOL));
        sub.add(new Option('Mod Folder Manager', 'Organize mods in Freeplay using folder selector', 'freeplayModFolder', BOOL));
        sub.add(new Option('Inline Search Filter', 'Type into the Freeplay search bar to filter the song list in place instead of opening the search popup',
            'freeplaySearchInline', BOOL));

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

        sub.add(new Option('Freeplay List Style', 'Background style of the Freeplay list items (search / mod folder / replay)',
            'freeplayListStyle', STRING, ['blur', 'win8', 'win10']));

        // 菜单/场景过渡 + 全局外观（主题、强调色）集中在这一段。
        var menu = cat.section('Menu', 'Menu');
        menu.add(new Option('Transition Type', 'Choose the transition animation style when switching scenes', 'transitionType', STRING, ['fade', 'pixel', 'loading']));
        menu.add(new Option('Blur Effect', 'Enable blur effect on background elements', 'blurEffects', BOOL));

        menu.add(new Option('Color Mode', 'Switch between dark and white mode', 'colorMode', STRING, ['dark', 'white']));
        menu.add(new Option('Control Theme', 'Choose the button style: auto (each UI uses its own style), win10 or win8',
            'controlTheme', STRING, ['auto', 'win10', 'win8']));
        menu.add(new Option('Options Style', 'Choose which options menu style to use', 'optionstype', STRING, ['new', 'psych', 'ke']));

        var accent = new Option('Accent Color', 'Primary color for selections, toggles, sliders and badges', 'uiAccent', COLOR);
        accent.setPalette(Option.ACCENT_PALETTE, Option.ACCENT_NAMES);
        menu.add(accent);

        var accentHover = new Option('Accent Hover', 'Secondary color for hover and light feedback', 'uiAccentHover', COLOR);
        accentHover.setPalette(Option.ACCENT_PALETTE, Option.ACCENT_NAMES);
        menu.add(accentHover);

        return cat;
    }
}