package options;

import backend.CustomChartData;
import backend.Paths;
import backend.Mods;
import states.FreeplayState;
import flixel.FlxG;

class ExtraSettingsSubState extends KESubMenu
{
	public function new()
	{
		var folders:Array<String> = ['custom'];
		#if sys
		folders = CustomChartData.listChartCategories();
		if (!folders.contains('custom')) folders.insert(0, 'custom');
		#end
		if (folders.length == 0) folders = ['custom'];
		var modFolders:Array<String> = Mods.getModDirectories();
		modFolders.sort(function(a:String, b:String):Int return a.toLowerCase() > b.toLowerCase() ? 1 : -1);
		modFolders.insert(0, '');
		var stages:Array<String> = Mods.mergeAllTextsNamed('data/stageList.txt');
		var characters:Array<String> = Mods.mergeAllTextsNamed('data/characterList.txt');
		if (!stages.contains('audiostage')) stages.insert(0, 'audiostage');
		if (!stages.contains('stage')) stages.insert(0, 'stage');
		if (!characters.contains('bf')) characters.insert(0, 'bf');
		if (!characters.contains('gf')) characters.insert(0, 'gf');
		if (!characters.contains('dad')) characters.insert(0, 'dad');
		if (!characters.contains('NONE')) characters.insert(0, 'NONE');

		var parent:KEOption = KEOption.createSubMenu(
			'Extra Settings',
			'Configure custom chart playback settings',
			[
				KEOption.createStringOption('Custom Chart Folder', 'Chart category used by custom chart mode', 'customChartFolder', folders, 'custom'),
				KEOption.createStringOption('Asset Mod Folder', 'Mod folder used for custom chart stages, characters, and other assets', 'customChartModFolder', modFolders, ''),
				KEOption.createStringOption('Stage', 'Stage used by custom charts', 'customChartStage', stages, 'audiostage'),
				KEOption.createStringOption('Player', 'Boyfriend character used by custom charts', 'customChartPlayer', characters, 'bf'),
				KEOption.createStringOption('Girlfriend', 'Girlfriend character used by custom charts', 'customChartGirlfriend', characters, 'gf'),
				KEOption.createStringOption('Opponent', 'Dad character used by custom charts', 'customChartOpponent', characters, 'dad'),
				KEOption.create('Play 8K as 4K', 'Map 8-key charts onto four playable columns', 'customChart8KTo4K', 'bool'),
				KEOption.create('Swap Player/Opponent Lanes', 'Swap the player and opponent note tracks without enabling Opponent Mode', 'customChartSwapSides', 'bool')
			],
			'',
			'Extra Settings'
		);
		super(parent);
	}

	override function closeMenu():Void
	{
		var previousChartCategory:String = Paths.currentChartCategory;
		var previousModDirectory:String = Mods.currentModDirectory;
		Paths.currentChartCategory = ClientPrefs.data.customChartFolder;
		FreeplayState.selectedCustomChartCategory = Paths.currentChartCategory;
		Mods.currentModDirectory = ClientPrefs.data.customChartModFolder;
		if ((previousChartCategory != Paths.currentChartCategory || previousModDirectory != Mods.currentModDirectory)
			&& FlxG.state != null && Std.isOfType(FlxG.state, FreeplayState))
			cast(FlxG.state, FreeplayState).onModFolderChanged();
		super.closeMenu();
	}
}