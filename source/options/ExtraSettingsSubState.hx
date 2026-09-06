package options;

import backend.CustomChartData;
import backend.Paths;
import backend.Mods;
import states.FreeplayState;
import flixel.FlxG;

#if sys
import sys.FileSystem;
#end

class ExtraSettingsSubState extends KESubMenu
{
    // 保存需要动态更新的选项引用
    var modFolderOption:KEOption;
    var stageOption:KEOption;
    var playerOption:KEOption;
    var girlfriendOption:KEOption;
    var opponentOption:KEOption;
    
    public function new()
    {
        var oldModDirectory:String = Mods.currentModDirectory;
        Mods.currentModDirectory = ClientPrefs.data.customChartModFolder;
        var parent = createMenu();
        Mods.currentModDirectory = oldModDirectory;
        super(parent);
        
        // 重要：在构造函数中立即初始化模组列表
        // 这样打开菜单时就会显示当前模组的资源
        refreshModDependentOptions(ClientPrefs.data.customChartModFolder);
    }
    
    function createMenu():KEOption
    {
        var folders:Array<String> = ['custom'];
        #if sys
        folders = CustomChartData.listChartCategories();
        if (!folders.contains('custom')) folders.insert(0, 'custom');
        #end
        if (folders.length == 0) folders = ['custom'];
        
        var modFolders:Array<String> = getModFolders();
        var stages:Array<String> = getStages();
        var characters:Array<String> = getCharacters();
        
        // 创建模组文件夹选项 - 保存引用
        modFolderOption = KEOption.createStringOption(
            'Asset Mod Folder',
            'Mod folder used for custom chart stages, characters, and other assets',
            'customChartModFolder',
            modFolders,
            ''
        );
        modFolderOption.confirmCallback = onModFolderConfirmed;
        
        // 创建依赖选项 - 保存引用
        stageOption = KEOption.createStringOption(
            'Stage',
            'Stage used by custom charts',
            'customChartStage',
            stages,
            'audiostage'
        );
        
        playerOption = KEOption.createStringOption(
            'Player',
            'Boyfriend character used by custom charts',
            'customChartPlayer',
            characters,
            'bf'
        );
        
        girlfriendOption = KEOption.createStringOption(
            'Girlfriend',
            'Girlfriend character used by custom charts',
            'customChartGirlfriend',
            characters,
            'gf'
        );
        
        opponentOption = KEOption.createStringOption(
            'Opponent',
            'Dad character used by custom charts',
            'customChartOpponent',
            characters,
            'dad'
        );

        stageOption.confirmCallback = onCustomResourceConfirmed;
        playerOption.confirmCallback = onCustomResourceConfirmed;
        girlfriendOption.confirmCallback = onCustomResourceConfirmed;
        opponentOption.confirmCallback = onCustomResourceConfirmed;
        
        return KEOption.createSubMenu(
            'Extra Settings',
            'Configure custom chart playback settings',
            [
                KEOption.createStringOption('Custom Chart Folder', 'Chart category used by custom chart mode', 'customChartFolder', folders, 'custom'),
                modFolderOption,
                stageOption,
                playerOption,
                girlfriendOption,
                opponentOption,
                KEOption.create('Play 8K as 4K', 'Map 8-key charts onto four playable columns', 'customChart8KTo4K', 'bool'),
                KEOption.create('Swap Player/Opponent Lanes', 'Swap the player and opponent note tracks without enabling Opponent Mode', 'customChartSwapSides', 'bool')
            ],
            '',
            'Extra Settings'
        );
    }
    
    function getModFolders():Array<String>
    {
        var modFolders:Array<String> = Mods.getModDirectories();
        modFolders.sort(function(a:String, b:String):Int return a.toLowerCase() > b.toLowerCase() ? 1 : -1);
        modFolders.insert(0, '');
        return modFolders;
    }
    
    function getStages():Array<String>
    {
        // 使用与 ChartingState 相同的方式加载 stage 列表
        var stages:Array<String> = Mods.mergeAllTextsNamed('data/stageList.txt');
        #if sys
        addResourceNames(stages, 'stages', ['.json', '.lua', '.hx']);
        #end
        if (!stages.contains('audiostage')) stages.insert(0, 'audiostage');
        if (!stages.contains('stage')) stages.insert(0, 'stage');
        return stages;
    }
    
    function getCharacters():Array<String>
    {
        // 使用与 ChartingState 相同的方式加载 character 列表
        var characters:Array<String> = Mods.mergeAllTextsNamed('data/characterList.txt');
        #if sys
        addResourceNames(characters, 'characters', ['.json']);
        #end
        // 过滤掉 -dead 和 -death 后缀的角色
        characters = characters.filter((name:String) -> (!name.endsWith('-dead') && !name.endsWith('-death')));
        if (!characters.contains('bf')) characters.insert(0, 'bf');
        if (!characters.contains('gf')) characters.insert(0, 'gf');
        if (!characters.contains('dad')) characters.insert(0, 'dad');
        if (!characters.contains('NONE')) characters.insert(0, 'NONE');
        return characters;
    }

    #if sys
    function addResourceNames(target:Array<String>, folder:String, extensions:Array<String>):Void
    {
        if (Mods.currentModDirectory == null || Mods.currentModDirectory.length == 0) return;

        var resourcePath:String = Paths.mods(Mods.currentModDirectory + '/' + folder);
        if (!FileSystem.exists(resourcePath)) return;

        for (fileName in FileSystem.readDirectory(resourcePath))
        {
            if (FileSystem.isDirectory(resourcePath + '/' + fileName)) continue;
            var lowerName:String = fileName.toLowerCase();
            var extension:String = null;
            for (candidate in extensions)
            {
                if (lowerName.endsWith(candidate))
                {
                    extension = candidate;
                    break;
                }
            }
            if (extension == null) continue;

            var resourceName:String = fileName.substring(0, fileName.length - extension.length);
            if (resourceName.length > 0 && !target.contains(resourceName)) target.push(resourceName);
        }
    }
    #end
    
    // 刷新依赖选项的列表
    function refreshModDependentOptions(newModFolder:String):Void
    {
        // 保存当前模组目录
        var oldModDir = Mods.currentModDirectory;
        
        // 临时切换到新模组目录以获取其资源列表
        Mods.currentModDirectory = newModFolder;
        
        // 获取新列表
        var newStages:Array<String> = getStages();
        var newCharacters:Array<String> = getCharacters();
        
        // 恢复模组目录
        Mods.currentModDirectory = oldModDir;
        
        // 更新 Stage 选项
        if (stageOption != null) {
            stageOption.updateStringOptions(newStages);
            // 如果当前值不在新列表中，重置为默认值
            if (!newStages.contains(ClientPrefs.data.customChartStage)) {
                ClientPrefs.data.customChartStage = 'audiostage';
                stageOption.value = 'audiostage';
                stageOption.curOption = newStages.indexOf('audiostage');
                if (stageOption.curOption < 0) stageOption.curOption = 0;
            }
        }
        
        // 更新 Player 选项
        if (playerOption != null) {
            playerOption.updateStringOptions(newCharacters);
            if (!newCharacters.contains(ClientPrefs.data.customChartPlayer)) {
                ClientPrefs.data.customChartPlayer = 'bf';
                playerOption.value = 'bf';
                playerOption.curOption = newCharacters.indexOf('bf');
                if (playerOption.curOption < 0) playerOption.curOption = 0;
            }
        }
        
        // 更新 Girlfriend 选项
        if (girlfriendOption != null) {
            girlfriendOption.updateStringOptions(newCharacters);
            if (!newCharacters.contains(ClientPrefs.data.customChartGirlfriend)) {
                ClientPrefs.data.customChartGirlfriend = 'gf';
                girlfriendOption.value = 'gf';
                girlfriendOption.curOption = newCharacters.indexOf('gf');
                if (girlfriendOption.curOption < 0) girlfriendOption.curOption = 0;
            }
        }
        
        // 更新 Opponent 选项
        if (opponentOption != null) {
            opponentOption.updateStringOptions(newCharacters);
            if (!newCharacters.contains(ClientPrefs.data.customChartOpponent)) {
                ClientPrefs.data.customChartOpponent = 'dad';
                opponentOption.value = 'dad';
                opponentOption.curOption = newCharacters.indexOf('dad');
                if (opponentOption.curOption < 0) opponentOption.curOption = 0;
            }
        }
        
        // 保存更新后的设置
        ClientPrefs.saveSettings();
    }

    function onModFolderConfirmed():Void
    {
        var newModDirectory:String = ClientPrefs.data.customChartModFolder;
        if (newModDirectory == null) newModDirectory = '';

        refreshModDependentOptions(newModDirectory);
        updateDisplay();
    }

    function onCustomResourceConfirmed():Void
    {
        ClientPrefs.saveSettings();
        updateDisplay();
    }
    
    override function closeMenu():Void
    {
        var previousModDirectory:String = Mods.currentModDirectory;
        var newModDirectory:String = ClientPrefs.data.customChartModFolder;
        
        // 如果模组目录改变了，刷新依赖选项
        if (previousModDirectory != newModDirectory && newModDirectory != null) {
            refreshModDependentOptions(newModDirectory);
        }
        
        var previousChartCategory:String = Paths.currentChartCategory;
        Paths.currentChartCategory = ClientPrefs.data.customChartFolder;
        FreeplayState.selectedCustomChartCategory = Paths.currentChartCategory;
        Mods.currentModDirectory = ClientPrefs.data.customChartModFolder;
        
        if ((previousChartCategory != Paths.currentChartCategory || previousModDirectory != Mods.currentModDirectory)
            && FlxG.state != null && Std.isOfType(FlxG.state, FreeplayState))
            cast(FlxG.state, FreeplayState).onModFolderChanged();
            
        super.closeMenu();
    }
}