package options.keoptions;

import options.Option;
import options.Option.OptionType;
import options.Win8CharmSettings;
import options.Win8CharmSettings.CharmEntry;

import backend.CustomChartData;
import backend.Mods;
import backend.Paths;
import states.FreeplayState;

import flixel.FlxG;

#if sys
import sys.FileSystem;
#end

/**
 * Extra Settings —— Win8 风格设置面板
 *
 * 继承 options.Win8CharmSettings 的单页设置页，三个分组：
 *   Custom Chart  自定义谱面用的分类 / mod 文件夹
 *   Resources     谱面用到的舞台与角色
 *   Playback      8K→4K 映射、交换玩家/对手轨道
 *
 * 换 mod 文件夹后靠 refreshModDependentOptions 刷新 Stage / 角色列表。
 */
class KEExtraSettingsSubState extends Win8CharmSettings
{
	// 资源列表
	var folders:Array<String> = ['custom'];
	var modFolders:Array<String> = [];
	var stages:Array<String> = [];
	var characters:Array<String> = [];

	// 选项引用（换 mod 文件夹时要就地更新它们的 options）
	var chartFolderOpt:Option;
	var modFolderOpt:Option;
	var stageOpt:Option;
	var playerOpt:Option;
	var girlfriendOpt:Option;
	var opponentOpt:Option;
	var eightKOpt:Option;
	var swapOpt:Option;

	public function new()
	{
		// 和旧版一致：在目标 mod 目录下取资源列表，这样打开菜单就能看到当前 mod 的素材
		var oldModDirectory:String = Mods.currentModDirectory;
		Mods.currentModDirectory = ClientPrefs.data.customChartModFolder;
		collectLists();
		Mods.currentModDirectory = oldModDirectory;

		super();
	}

	// =========================================================
	// 单页模式的总标题
	// =========================================================
	override public function getPageTitle():String
		return 'Extra Settings';

	override public function getPageDescription():String
		return 'Chart folder, stage and character resources, playback options';

	// =========================================================
	// Charm 声明
	// =========================================================
	override public function buildCharms():Array<CharmEntry>
	{
		chartFolderOpt = new Option('Custom Chart Folder', 'Chart category used by custom chart mode',
			'customChartFolder', STRING, folders);

		modFolderOpt = new Option('Asset Mod Folder', 'Mod folder used for custom chart stages, characters and other assets',
			'customChartModFolder', STRING, modFolders);
		modFolderOpt.onChange = function() { onModFolderChanged(); };

		stageOpt = new Option('Stage', 'Stage used by custom charts',
			'customChartStage', STRING, stages);

		playerOpt = new Option('Player', 'Boyfriend character used by custom charts',
			'customChartPlayer', STRING, characters);

		girlfriendOpt = new Option('Girlfriend', 'Girlfriend character used by custom charts',
			'customChartGirlfriend', STRING, characters);

		opponentOpt = new Option('Opponent', 'Dad character used by custom charts',
			'customChartOpponent', STRING, characters);

		eightKOpt = new Option('Play 8K as 4K', 'Map 8-key charts onto four playable columns',
			'customChart8KTo4K', BOOL);

		swapOpt = new Option('Swap Player/Opponent Lanes', 'Swap the player and opponent note tracks without enabling Opponent Mode',
			'customChartSwapSides', BOOL);

		return [
			{
				id: 'chart',
				title: 'Custom Chart',
				description: 'Which chart category and mod folder custom charts use',
				options: [chartFolderOpt, modFolderOpt]
			},
			{
				id: 'resources',
				title: 'Resources',
				description: 'Stage and characters used when playing custom charts',
				options: [stageOpt, playerOpt, girlfriendOpt, opponentOpt]
			},
			{
				id: 'playback',
				title: 'Playback',
				description: 'How custom charts are mapped onto the playfield',
				options: [eightKOpt, swapOpt]
			}
		];
	}

	// =========================================================
	// 资源列表
	// =========================================================
	function collectLists():Void
	{
		folders = ['custom'];
		#if sys
		folders = CustomChartData.listChartCategories();
		if (!folders.contains('custom')) folders.insert(0, 'custom');
		#end
		if (folders.length == 0) folders = ['custom'];

		modFolders = getModFolders();
		stages = getStages();
		characters = getCharacters();
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

	// =========================================================
	// 换 mod 文件夹 → 刷新依赖选项
	// =========================================================
	function onModFolderChanged():Void
	{
		var newModDirectory:String = ClientPrefs.data.customChartModFolder;
		if (newModDirectory == null) newModDirectory = '';

		refreshModDependentOptions(newModDirectory);
		requestPanelRebuild();
	}

	function refreshModDependentOptions(newModFolder:String):Void
	{
		// 临时切到新模组目录以获取它的资源列表
		var oldModDir:String = Mods.currentModDirectory;
		Mods.currentModDirectory = newModFolder;

		var newStages:Array<String> = getStages();
		var newCharacters:Array<String> = getCharacters();

		Mods.currentModDirectory = oldModDir;

		// Stage
		if (stageOpt != null)
		{
			stageOpt.options = newStages;
			if (!newStages.contains(ClientPrefs.data.customChartStage))
			{
				ClientPrefs.data.customChartStage = 'audiostage';
				stageOpt.setValue('audiostage');
			}
			var stageIdx:Int = newStages.indexOf(ClientPrefs.data.customChartStage);
			stageOpt.curOption = stageIdx < 0 ? 0 : stageIdx;
		}

		// Player / Girlfriend / Opponent
		refreshCharacterOption(playerOpt, newCharacters, 'customChartPlayer', 'bf');
		refreshCharacterOption(girlfriendOpt, newCharacters, 'customChartGirlfriend', 'gf');
		refreshCharacterOption(opponentOpt, newCharacters, 'customChartOpponent', 'dad');

		ClientPrefs.saveSettings();
	}

	function refreshCharacterOption(opt:Option, list:Array<String>, variable:String, fallback:String):Void
	{
		if (opt == null) return;

		opt.options = list;

		var cur:String = Reflect.getProperty(ClientPrefs.data, variable);
		if (!list.contains(cur))
		{
			Reflect.setProperty(ClientPrefs.data, variable, fallback);
			opt.setValue(fallback);
			cur = fallback;
		}
		var idx:Int = list.indexOf(cur);
		opt.curOption = idx < 0 ? 0 : idx;
	}

	// =========================================================
	// 关闭：沿用旧版 closeMenu 的收尾逻辑
	// =========================================================
	override public function closeCharmBar():Void
	{
		var previousModDirectory:String = Mods.currentModDirectory;
		var newModDirectory:String = ClientPrefs.data.customChartModFolder;

		// 如果模组目录改变了，刷新依赖选项
		if (previousModDirectory != newModDirectory && newModDirectory != null)
			refreshModDependentOptions(newModDirectory);

		var previousChartCategory:String = Paths.currentChartCategory;
		Paths.currentChartCategory = ClientPrefs.data.customChartFolder;
		FreeplayState.selectedCustomChartCategory = Paths.currentChartCategory;
		Mods.currentModDirectory = ClientPrefs.data.customChartModFolder;

		if ((previousChartCategory != Paths.currentChartCategory || previousModDirectory != Mods.currentModDirectory)
			&& FlxG.state != null && Std.isOfType(FlxG.state, FreeplayState))
			cast(FlxG.state, FreeplayState).onModFolderChanged();

		ClientPrefs.saveSettings();
		close();
	}
}
