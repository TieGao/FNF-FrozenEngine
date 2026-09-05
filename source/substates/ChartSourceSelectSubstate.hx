package substates;

import backend.Paths;
import backend.ui.PsychUIButton;
import backend.ui.PsychUIRadioGroup;
import backend.Difficulty;
import backend.CustomChartData;

#if sys
import sys.FileSystem;
import haxe.Json;
#end

class ChartSourceSelectSubstate extends MusicBeatSubstate
{
	public static final chartRoot:String = 'mods/charts';
	public static final categories:Array<String> = ['v_slice'];

	// 修改回调签名，增加 variant 参数
	public var onSelect:Null<String->String->String->String->Void> = null; // category, path, difficulty, variant
	public var onCancel:Null<Void->Void> = null;

	var background:FlxSprite;
	var panel:FlxSprite;
	var titleText:FlxText;
	var categoryButtons:FlxTypedGroup<PsychUIButton> = new FlxTypedGroup<PsychUIButton>();
	var itemButtons:FlxTypedGroup<PsychUIButton> = new FlxTypedGroup<PsychUIButton>();
	var itemList:Array<ChartSourceEntry> = [];
	var currentCategory:String = 'fnf';
	
	// 导航状态
	var currentPage:Int = 0;
	var itemsPerPage:Int = 8;
	var totalPages:Int = 1;
	
	// 导航按钮
	var prevPageBtn:PsychUIButton;
	var nextPageBtn:PsychUIButton;
	var pageText:FlxText;
	
	// 动态文本
	var dynamicTexts:Array<FlxText> = [];

	// 面包屑导航
	var breadcrumbText:FlxText;
	var backBtn:PsychUIButton;
	
	// 当前选中的歌曲目录
	var currentSongDir:String = null;
	
	// 存储当前选中的条目，用于难度选择
	var selectedEntry:ChartSourceEntry = null;

	// 修改构造函数签名
	public function new(?onSelectCallback:String->String->String->String->Void, ?onCancelCallback:Void->Void)
	{
		super();
		this.onSelect = onSelectCallback;
		this.onCancel = onCancelCallback;
		
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	override function create()
	{
		persistentUpdate = true;
		persistentDraw = true;

		// 背景
		background = new FlxSprite().makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), FlxColor.BLACK);
		background.alpha = 0.6;
		background.scrollFactor.set();
		add(background);

		// 面板
		panel = new FlxSprite(80, 60).makeGraphic(Std.int(FlxG.width - 160), Std.int(FlxG.height - 120), FlxColor.fromString('0xFF1E1E1E'));
		panel.scrollFactor.set();
		add(panel);

		// 标题
		titleText = new FlxText(0, 90, FlxG.width, 'Select chart from mods/charts', 28);
		titleText.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER);
		titleText.scrollFactor.set();
		add(titleText);

		// 分类按钮
		var availableCategories:Array<String> = collectChartCategories();
		if (availableCategories.length > 0) currentCategory = availableCategories[0];
		var catY:Float = 150;
		for (i in 0...availableCategories.length)
		{
			var category:String = availableCategories[i];
			var btn:PsychUIButton = new PsychUIButton(120 + i * 220, catY, '  ' + getCategoryTitle(category), function()
			{
				currentCategory = category;
				currentPage = 0;
				currentSongDir = null;
				selectedEntry = null;
				refreshItemList();
			});
			btn.resize(180, 32);
			btn.text.alignment = LEFT;
			btn.normalStyle.bgColor = (category == currentCategory) ? FlxColor.fromString('0xFF3B82F6') : FlxColor.fromString('0xFF2A2A2A');
			btn.normalStyle.textColor = FlxColor.WHITE;
			btn.scrollFactor.set();
			categoryButtons.add(btn);
			add(btn);
		}

		// 面包屑导航 - 返回按钮
		backBtn = new PsychUIButton(120, 195, '< Back to Songs', function()
		{
			currentSongDir = null;
			currentPage = 0;
			selectedEntry = null;
			refreshItemList();
		});
		backBtn.resize(160, 28);
		backBtn.normalStyle.bgColor = FlxColor.fromString('0xFF4A4A4A');
		backBtn.normalStyle.textColor = FlxColor.WHITE;
		backBtn.scrollFactor.set();
		backBtn.visible = false;
		add(backBtn);

		// 面包屑文本
		breadcrumbText = new FlxText(300, 198, 0, '', 18);
		breadcrumbText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.GRAY, LEFT);
		breadcrumbText.scrollFactor.set();
		breadcrumbText.visible = false;
		add(breadcrumbText);

		// 分页按钮
		prevPageBtn = new PsychUIButton(120, FlxG.height - 140, '< Previous', function()
		{
			if (currentPage > 0)
			{
				currentPage--;
				selectedEntry = null;
				refreshItemList();
			}
		});
		prevPageBtn.resize(120, 32);
		prevPageBtn.scrollFactor.set();
		prevPageBtn.visible = false;
		add(prevPageBtn);

		nextPageBtn = new PsychUIButton(FlxG.width - 240, FlxG.height - 140, 'Next >', function()
		{
			if (currentPage < totalPages - 1)
			{
				currentPage++;
				selectedEntry = null;
				refreshItemList();
			}
		});
		nextPageBtn.resize(120, 32);
		nextPageBtn.scrollFactor.set();
		nextPageBtn.visible = false;
		add(nextPageBtn);

		pageText = new FlxText(0, FlxG.height - 135, 0, 'Page 1/1', 20);
		pageText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER);
		pageText.screenCenter(X);
		pageText.scrollFactor.set();
		pageText.visible = false;
		add(pageText);

		// 取消按钮
		var cancelBtn:PsychUIButton = new PsychUIButton(FlxG.width - 250, FlxG.height - 120, 'Cancel', function()
		{
			if (onCancel != null) onCancel();
			close();
		});
		cancelBtn.resize(120, 32);
		cancelBtn.normalStyle.bgColor = FlxColor.RED;
		cancelBtn.normalStyle.textColor = FlxColor.WHITE;
		cancelBtn.scrollFactor.set();
		add(cancelBtn);

		refreshItemList();
		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (FlxG.keys.justPressed.ESCAPE)
		{
			if (onCancel != null) onCancel();
			close();
		}
		
		if (FlxG.keys.justPressed.LEFT)
		{
			if (currentPage > 0)
			{
				currentPage--;
				selectedEntry = null;
				refreshItemList();
			}
		}
		else if (FlxG.keys.justPressed.RIGHT)
		{
			if (currentPage < totalPages - 1)
			{
				currentPage++;
				selectedEntry = null;
				refreshItemList();
			}
		}
	}

	function refreshItemList():Void
	{
		// 清除按钮
		for (btn in itemButtons.members)
		{
			remove(btn, true);
		}
		itemButtons.clear();
		
		// 清除动态文本
		for (txt in dynamicTexts)
		{
			remove(txt, true);
		}
		dynamicTexts = [];

		var entries:Array<ChartSourceEntry> = [];
		
		if (currentSongDir == null)
		{
			// 显示歌曲目录
			entries = collectSongDirs(currentCategory);
		}
		else
		{
			// 显示歌曲目录下的谱面文件
			entries = collectChartFiles(currentCategory, currentSongDir);
		}
		
		itemList = entries;
		
		totalPages = Std.int(Math.max(1, Math.ceil(entries.length / itemsPerPage)));
		
		if (currentPage >= totalPages) currentPage = totalPages - 1;
		if (currentPage < 0) currentPage = 0;
		
		var listY:Float = (currentSongDir == null) ? 240 : 235;
		var index:Int = 0;
		
		var startIndex:Int = currentPage * itemsPerPage;
		var endIndex:Int = Std.int(Math.min(startIndex + itemsPerPage, entries.length));

		// 更新面包屑
		if (currentSongDir != null)
		{
			backBtn.visible = true;
			breadcrumbText.visible = true;
			breadcrumbText.text = getCategoryTitle(currentCategory) + ' / ' + currentSongDir;
		}
		else
		{
			backBtn.visible = false;
			breadcrumbText.visible = false;
		}

		if (entries.length < 1)
		{
			var msg:String = (currentSongDir == null) 
				? 'No song folders found in ' + currentCategory + '.\nCreate folders in: mods/charts/' + currentCategory + '/'
				: 'No chart files found in ' + currentSongDir + '.\nPlace .json files in: mods/charts/' + currentCategory + '/' + currentSongDir + '/';
			
			var emptyText:FlxText = new FlxText(120, listY, FlxG.width - 240, msg, 18);
			emptyText.setFormat(null, 18, FlxColor.GRAY, LEFT);
			emptyText.scrollFactor.set();
			add(emptyText);
			dynamicTexts.push(emptyText);
			
			prevPageBtn.visible = false;
			nextPageBtn.visible = false;
			pageText.visible = false;
			
			updateCategoryHighlights();
			return;
		}

		for (i in startIndex...endIndex)
		{
			var entry:ChartSourceEntry = entries[i];
			if (entry == null) continue;

			var displayLabel:String = entry.label;
			if (displayLabel.length > 50)
				displayLabel = displayLabel.substring(0, 48) + '...';

			var button:PsychUIButton = createItemButton(entry, listY + index * 36, displayLabel);
			button.resize(FlxG.width - 300, 24);
			button.text.alignment = LEFT;
			button.normalStyle.bgColor = FlxColor.fromString('0xFF2F2F2F');
			button.normalStyle.textColor = FlxColor.WHITE;
			button.scrollFactor.set();
			itemButtons.add(button);
			add(button);
			index++;
		}

		if (totalPages > 1)
		{
			prevPageBtn.visible = true;
			nextPageBtn.visible = true;
			pageText.visible = true;
			
			prevPageBtn.active = (currentPage > 0);
			nextPageBtn.active = (currentPage < totalPages - 1);
			
			prevPageBtn.alpha = prevPageBtn.active ? 1 : 0.5;
			nextPageBtn.alpha = nextPageBtn.active ? 1 : 0.5;
			
			pageText.text = 'Page ${currentPage + 1}/${totalPages}';
			pageText.screenCenter(X);
		}
		else
		{
			prevPageBtn.visible = false;
			nextPageBtn.visible = false;
			pageText.visible = false;
		}

		updateCategoryHighlights();
	}

	function createItemButton(entry:ChartSourceEntry, y:Float, displayLabel:String):PsychUIButton
	{
		var isDirectory:Bool = entry.type == 'directory';
		
		return new PsychUIButton(120, y, '  ' + (isDirectory ? '📁 ' : '📄 ') + displayLabel, function()
		{
			if (isDirectory)
			{
				// 进入歌曲目录
				currentSongDir = entry.path;
				currentPage = 0;
				selectedEntry = null;
				refreshItemList();
			}
			else
			{
				// 选择谱面文件
				selectedEntry = entry;
				
				// 如果是 V-Slice 类别，需要选择难度
				if (entry.category == 'v_slice')
				{
					showDifficultySelection(entry);
				}
				else
				{
					close();
					if (onSelect != null) onSelect(entry.category, entry.path, null, entry.variant);
				}
			}
		});
	}

	/**
	 * 收集歌曲目录
	 */
	static function collectSongDirs(category:String):Array<ChartSourceEntry>
	{
		ensureChartRoot();
		var dir:String = '$chartRoot/$category';
		var result:Array<ChartSourceEntry> = [];
		
		#if sys
		if (!FileSystem.exists(dir)) return result;
		
		var actualDir:String = findCaseInsensitivePath(chartRoot, category);
		if (actualDir == null) return result;
		
		var items:Array<String> = FileSystem.readDirectory(actualDir);
		
		for (item in items)
		{
			if (item.startsWith('.')) continue;
			var itemPath:String = '$actualDir/$item';
			if (FileSystem.isDirectory(itemPath))
			{
				// 检查目录下是否有谱面文件
				var hasCharts:Bool = false;
				var subFiles:Array<String> = FileSystem.readDirectory(itemPath);
				for (subFile in subFiles)
				{
					if (CustomChartData.isChartFile(subFile))
					{
						hasCharts = true;
						break;
					}
				}
				
				if (hasCharts)
				{
					result.push({
						label: item,
						path: itemPath,
						category: category,
						variant: null,
						type: 'directory',
						name: item
					});
				}
			}
		}
		#end
		
		result.sort((a, b) -> (a.label.toLowerCase() > b.label.toLowerCase()) ? 1 : -1);
		return result;
	}

	static function collectChartCategories():Array<String>
	{
		var result:Array<String> = [];
		#if sys
		ensureChartRoot();
		for (item in FileSystem.readDirectory(chartRoot))
			if (!item.startsWith('.') && FileSystem.isDirectory('$chartRoot/$item')) result.push(item);
		#end
		result.sort((a, b) -> (a.toLowerCase() > b.toLowerCase()) ? 1 : -1);
		return result;
	}

	/**
	 * 收集歌曲目录下的谱面文件
	 */
	static function collectChartFiles(category:String, songDir:String):Array<ChartSourceEntry>
	{
		var result:Array<ChartSourceEntry> = [];
		
		#if sys
		var baseDir:String = '$chartRoot/$category';
		var actualBaseDir:String = findCaseInsensitivePath(chartRoot, category);
		if (actualBaseDir == null) return result;
		
		var actualSongDir:String = FileSystem.exists(songDir) ? songDir : findCaseInsensitivePath(actualBaseDir, songDir);
		if (actualSongDir == null) return result;
		
		var files:Array<String> = FileSystem.readDirectory(actualSongDir);
		for (file in files)
		{
			var childPath:String = '$actualSongDir/$file';
			if (!file.startsWith('.') && FileSystem.isDirectory(childPath))
				result.push({label: file, path: childPath, category: category, variant: null, type: 'directory', name: childPath});
		}
		
		switch (category)
		{
			case 'v_slice':
				// V-Slice: 收集所有非 metadata 的 JSON 文件
				var chartFiles:Array<{fileName:String, fullPath:String, displayName:String, variant:String}> = [];
				
				for (file in files)
				{
					if (!CustomChartData.isChartFile(file)) continue;
					var lower:String = file.toLowerCase();
					if (!lower.endsWith('.json')) continue;
					
					// 匹配各种 chart 文件格式
					if (lower == 'chart.json' || 
						lower.indexOf('chart-') != -1 || 
						lower.indexOf('_chart') != -1 ||
						lower.indexOf('-chart') != -1)
					{
						var variant:String = getVariantNameFromFile(file);
						var displayName:String = variant == 'default' ? 'Default' : variant.charAt(0).toUpperCase() + variant.substr(1);
						
						chartFiles.push({
							fileName: file,
							fullPath: '$actualSongDir/$file',
							displayName: displayName,
							variant: variant
						});
					}
				}
				
				// 如果没有找到，降级为所有非 metadata 的 JSON
				if (chartFiles.length == 0)
				{
					for (file in files)
					{
						if (CustomChartData.isChartFile(file) && file.toLowerCase().endsWith('.json'))
						{
							var variant:String = getVariantNameFromFile(file);
							var displayName:String = variant == 'default' ? 'Default' : variant.charAt(0).toUpperCase() + variant.substr(1);
							
							chartFiles.push({
								fileName: file,
								fullPath: '$actualSongDir/$file',
								displayName: displayName,
								variant: variant
							});
						}
					}
				}
				
				for (cf in chartFiles)
				{
					result.push({
						label: cf.displayName,
						path: cf.fullPath,
						category: category,
						variant: cf.variant,
						type: 'file',
						name: cf.fileName
					});
				}
				
			default:
				// Non V-Slice categories use the file extension to select the loader.
				for (file in files)
				{
					if (CustomChartData.isChartFile(file))
						result.push({label: file, path: '$actualSongDir/$file', category: category,
							variant: null, type: 'file', name: file});
				}
		}
		#end
		
		result.sort((a, b) -> (a.label.toLowerCase() > b.label.toLowerCase()) ? 1 : -1);
		return result;
	}

	/**
	 * 显示 V-Slice 难度选择对话框
	 */
	function showDifficultySelection(entry:ChartSourceEntry):Void
	{
		#if sys
		persistentUpdate = false;
		// 读取 V-Slice 元数据获取可用难度列表
		var folderPath:String = entry.path.substring(0, entry.path.lastIndexOf('/'));
		var metadataPath:String = null;
		
		// 尝试查找 metadata 文件
		var files:Array<String> = FileSystem.readDirectory(folderPath);
		for (file in files)
		{
			if (file.startsWith('.')) continue;
			var lower:String = file.toLowerCase();
			if (lower.indexOf('metadata') != -1 && lower.endsWith('.json'))
			{
				metadataPath = '$folderPath/$file';
				break;
			}
		}
		
		if (metadataPath == null || !FileSystem.exists(metadataPath))
		{
			// 没有 metadata 文件，直接加载，传递 variant
			close();
			persistentUpdate = true;
			if (onSelect != null) onSelect(entry.category, entry.path, null, entry.variant);
			return;
		}
		
		// 解析 metadata 获取难度列表
		try
		{
			var metadataJson:String = File.getContent(metadataPath);
			var metadata:Dynamic = Json.parse(metadataJson);
			var diffs:Array<String> = null;
			
			if (metadata.playData != null && metadata.playData.difficulties != null)
			{
				diffs = cast metadata.playData.difficulties;
			}
			
			if (diffs == null || diffs.length < 1)
			{
				close();
				persistentUpdate = true;
				if (onSelect != null) onSelect(entry.category, entry.path, null, entry.variant);
				return;
			}
			
			// metadata 的 difficulties 是全曲通用列表；当前变体实际包含的难度
			// 由该 chart 的 notes 字段决定。
			var displayDiffs:Array<String> = getChartDifficulties(entry.path, diffs);
			if (displayDiffs.length < 1) displayDiffs = diffs;
			
			// 存储当前选中的变体，以便在回调中使用
			var selectedVariant:String = entry.variant;
			
			var substate:MusicBeatSubstate = new VSliceDifficultySelectSubstate(
				displayDiffs,
				function(selectedDiff:String)
				{
					close();
					persistentUpdate = true;
					if (onSelect != null) onSelect(entry.category, entry.path, selectedDiff, selectedVariant);
				},
				function()
				{
					persistentUpdate = true;
					selectedEntry = null;
				}
			);
			openSubState(substate);
		}
		catch (e:Dynamic)
		{
			// 解析失败，直接加载，传递 variant
			close();
			persistentUpdate = true;
			if (onSelect != null) onSelect(entry.category, entry.path, null, entry.variant);
		}
		#else
		// 非 sys 平台，直接加载，传递 variant
		close();
		if (onSelect != null) onSelect(entry.category, entry.path, null, entry.variant);
		#end
	}
	
	#if sys
	/**
	 * 获取当前 V-Slice chart 实际包含的难度列表。
	 */
	static function getChartDifficulties(chartPath:String, metadataDifficulties:Array<String>):Array<String>
	{
		try
		{
			var chart:Dynamic = Json.parse(File.getContent(chartPath));
			if (chart == null || chart.notes == null) return [];

			var chartFields:Array<String> = Reflect.fields(chart.notes);
			var chartDifficulties:Array<String> = [];
			for (difficulty in metadataDifficulties)
			{
				if (chartFields.indexOf(difficulty) != -1) chartDifficulties.push(difficulty);
			}

			// 兼容 chart 中存在但 metadata 未列出的难度。
			for (difficulty in chartFields)
			{
				if (chartDifficulties.indexOf(difficulty) == -1) chartDifficulties.push(difficulty);
			}
			return chartDifficulties;
		}
		catch (e:Dynamic)
		{
			return [];
		}
	}
	#end

	function updateCategoryHighlights():Void
	{
		for (btn in categoryButtons.members)
		{
			var isSelected:Bool = btn.text.text.toLowerCase().indexOf(getCategoryTitle(currentCategory).toLowerCase()) != -1;
			btn.normalStyle.bgColor = isSelected ? FlxColor.fromString('0xFF3B82F6') : FlxColor.fromString('0xFF2A2A2A');
		}
	}

	static function getCategoryTitle(category:String):String
	{
		switch (category)
		{
			case 'fnf': return 'FNF';
			case 'v_slice': return 'V-Slice';
			case 'osu_mania': return 'Osu Mania';
			default: return category;
		}
	}

	static function ensureChartRoot():Void
	{
		#if sys
		createDirectoryRecursive(chartRoot);
		for (cat in categories)
		{
			var path:String = '$chartRoot/$cat';
			createDirectoryRecursive(path);
		}
		#end
	}
	
	#if sys
	static function createDirectoryRecursive(path:String):Void
	{
		if (FileSystem.exists(path)) return;
		
		var parent:String = path.substring(0, path.lastIndexOf('/'));
		if (parent != '' && !FileSystem.exists(parent))
		{
			createDirectoryRecursive(parent);
		}
		
		try {
			FileSystem.createDirectory(path);
		} catch (e:Dynamic) {}
	}
	#end
	
	#if sys
	static function findCaseInsensitivePath(basePath:String, targetName:String):String
	{
		if (!FileSystem.exists(basePath)) return null;
		
		var exactPath:String = '$basePath/$targetName';
		if (FileSystem.exists(exactPath))
		{
			return exactPath;
		}
		
		var targetLower:String = targetName.toLowerCase();
		var items:Array<String> = FileSystem.readDirectory(basePath);
		for (item in items)
		{
			if (item.toLowerCase() == targetLower)
			{
				return '$basePath/$item';
			}
		}
		
		return null;
	}
	#end

	/**
	* 从文件名中动态提取变体名称。
	* 例如: chart-erect.json -> erect，chart.json -> default。
	*/
	public static function getVariantNameFromFile(fileName:String):String
	{
		var nameWithoutExt:String = fileName.substring(0, fileName.lastIndexOf('.'));
		var normalized:String = nameWithoutExt.toLowerCase().replace('_', '-');
		var parts:Array<String> = normalized.split('-');
		var chartIndex:Int = parts.indexOf('chart');
		var metadataIndex:Int = parts.indexOf('metadata');

		if (chartIndex >= 0 && chartIndex + 1 < parts.length)
			return parts.slice(chartIndex + 1).join('-');

		if (metadataIndex >= 0 && metadataIndex + 1 < parts.length)
			return parts.slice(metadataIndex + 1).join('-');

		if (chartIndex >= 0 || metadataIndex >= 0 || normalized == 'chart' || normalized == 'metadata')
			return 'default';

		return normalized;
	}
}

/**
 * V-Slice 难度选择子状态（样式与主对话框统一）
 */
class VSliceDifficultySelectSubstate extends MusicBeatSubstate
{
	var diffs:Array<String>;
	var onConfirm:Null<String->Void>;
	var onCancel:Null<Void->Void>;
	
	var panel:FlxSprite;
	var titleText:FlxText;
	var radioGroup:PsychUIRadioGroup;
	var confirmBtn:PsychUIButton;
	var cancelBtn:PsychUIButton;
	
	public function new(difficulties:Array<String>, ?onConfirmCallback:String->Void, ?onCancelCallback:Void->Void)
	{
		super();
		this.diffs = difficulties;
		this.onConfirm = onConfirmCallback;
		this.onCancel = onCancelCallback;
		
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}
	
	override function create()
	{
		persistentUpdate = true;
		persistentDraw = true;
		
		// 遮罩背景（与主对话框色调一致）
		var bg:FlxSprite = new FlxSprite().makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), FlxColor.BLACK);
		bg.alpha = 0.7;
		bg.scrollFactor.set();
		add(bg);
		
		// 面板（与主面板颜色一致）
		var padding:Int = 30;
		var itemHeight:Int = 40;
		var titleHeight:Int = 35;
		var btnHeight:Int = 40;
		var panelWid:Int = 480;
		var panelHei:Int = padding + titleHeight + 20 + diffs.length * itemHeight + 20 + btnHeight + padding;
		if (panelHei < 280) panelHei = 280;
		
		panel = new FlxSprite((FlxG.width - panelWid) / 2, (FlxG.height - panelHei) / 2);
		panel.makeGraphic(panelWid, panelHei, FlxColor.fromString('0xFF1E1E1E'));
		panel.scrollFactor.set();
		add(panel);
		
		// 标题
		titleText = new FlxText(0, panel.y + 20, panelWid, 'SELECT DIFFICULTY', 26);
		titleText.setFormat(Paths.font('vcr.ttf'), 26, FlxColor.WHITE, CENTER);
		titleText.scrollFactor.set();
		add(titleText);
		
		// 单选按钮组
		var startY:Float = panel.y + 60;
		radioGroup = new PsychUIRadioGroup(
			panel.x + 40,
			startY,
			diffs,
			36,
			Std.int(Math.min(diffs.length, 10)),
			false,
			panelWid - 80
		);
		radioGroup.scrollFactor.set();
		radioGroup.checked = 0;
		add(radioGroup);
		
		// 按钮行
		var btnY:Float = panel.y + panelHei - 50;
		confirmBtn = new PsychUIButton(panel.x + 40, btnY, 'LOAD', function()
		{
			var selectedDiff:String = diffs[radioGroup.checked];
			if (onConfirm != null) onConfirm(selectedDiff);
			close();
		});
		confirmBtn.resize(120, 36);
		confirmBtn.normalStyle.bgColor = FlxColor.fromString('0xFF3B82F6');
		confirmBtn.normalStyle.textColor = FlxColor.WHITE;
		confirmBtn.scrollFactor.set();
		add(confirmBtn);
		
		cancelBtn = new PsychUIButton(panel.x + panelWid - 160, btnY, 'CANCEL', function()
		{
			if (onCancel != null) onCancel();
			close();
		});
		cancelBtn.resize(120, 36);
		cancelBtn.normalStyle.bgColor = FlxColor.fromString('0xFF4A4A4A');
		cancelBtn.normalStyle.textColor = FlxColor.WHITE;
		cancelBtn.scrollFactor.set();
		add(cancelBtn);
		
		super.create();
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (FlxG.keys.justPressed.ESCAPE)
		{
			if (onCancel != null) onCancel();
			close();
		}
		
		if (FlxG.keys.justPressed.UP)
		{
			radioGroup.checked = Std.int(Math.max(0, radioGroup.checked - 1));
		}
		else if (FlxG.keys.justPressed.DOWN)
		{
			radioGroup.checked = Std.int(Math.min(diffs.length - 1, radioGroup.checked + 1));
		}
		else if (FlxG.keys.justPressed.ENTER)
		{
			var selectedDiff:String = diffs[radioGroup.checked];
			if (onConfirm != null) onConfirm(selectedDiff);
			close();
		}
		
	}
}

typedef ChartSourceEntry =
{
	var label:String;
	var path:String;
	var category:String;
	@:optional var variant:String; // 变体名称 (erect, pico, default 等)
	@:optional var type:String; // 'directory' 或 'file'
	@:optional var name:String; // 文件名或目录名
}