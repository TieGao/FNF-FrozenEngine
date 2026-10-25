package substates;

import backend.Paths;
import backend.MouseMove;
import backend.ui.PsychUIButton;
import backend.ui.PsychUIInputText;
import backend.CustomChartData;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxSpriteUtil;
import options.objects.OptionInput;
import options.objects.win10.Win10SearchBar;

#if sys
import sys.FileSystem;
import haxe.Json;
#end

/**
 * 谱面来源选择器 —— Windows 资源管理器式双栏浏览器。
 * 左栏：目录树（content〔自定义谱面 CustomCharts + 原版歌曲包 VanillaSongs〕、assets、mods
 * 三个根，懒加载 + 谱面数量统计）。
 * 右栏：当前目录内容（文件夹在前、谱面文件在后），顶栏面包屑 + 搜索框。
 * 回调签名保持不变：onSelect(category, path, difficulty, variant)。
 */
class ChartSourceSelectSubstate extends MusicBeatSubstate
{
	public static final chartRoot:String = Paths.CHART_ROOT;
	public static final categories:Array<String> = ['v_slice'];

	public static inline final ROOT_ASSETS:String = 'assets';
	public static inline final ROOT_MODS:String = 'mods';
	public static inline final V_SLICE:String = 'v_slice';
	/** content 下的原版歌曲内容包目录（Erect / PicoMix / BFMix / Collab）。 */
	public static inline final VANILLA_PACKS:String = 'VanillaSongs';

	public var onSelect:Null<String->String->String->String->Void> = null; // category, path, difficulty, variant
	public var onCancel:Null<Void->Void> = null;

	// ---- 布局 ----
	// 本界面画在哪台相机上（ChartingState 的 camUI）。update 阶段 FlxGroup 不做默认相机
	// 交换（只有 draw 做），交互组件不显式指派 cameras 的话，命中判定与裁剪换算都会
	// 解析到 defaults[0] —— 也就是滚动的游戏相机上。见 .agents/skills/flixel-clip。
	var uiCamera:FlxCamera;
	var background:FlxSprite;
	var panel:FlxSprite;
	var titleText:FlxText;
	var breadcrumbButtons:Array<PsychUIButton> = [];
	var searchBar:Win10SearchBar;
	var statusText:FlxText;
	var emptyText:FlxText;
	var cancelBtn:PsychUIButton;
	var divider:FlxSprite;

	// 面板内两栏区域
	var treeX:Float; var treeY:Float; var treeW:Float; var treeH:Float;
	var listX:Float; var listY:Float; var listW:Float; var listH:Float;
	static inline final ROW_H:Int = 28;

	// ---- 滚动（backend.MouseMove：拖拽 + 惯性 + 滚轮） ----
	var treeScroller:MouseMove;
	var listScroller:MouseMove;
	var pressY:Float = 0; // 按下那帧的指针 Y，用于把"拖过再松开"从点击里剔除
	var pressTracked:Bool = false;
	var pressTreeScroll:Float = 0; // 按下那帧两栏的滚动位置，把"按下期间列表还在动"从点击里剔除
	var pressListScroll:Float = 0;

	// ---- 目录树 ----
	var rootNode:ChartDirNode; // 虚拟根，children 为三个真实根
	var treeRows:Array<ChartDirNode> = [];
	var treeScroll:Float = 0;
	var treeButtons:Array<PsychUIButton> = []; // 名称按钮(与 treeRows 一一对应)
	var treeButtonNodes:Array<ChartDirNode> = []; // 名称按钮对应的节点
	var treeArrowButtons:Array<PsychUIButton> = []; // 箭头点击区按钮(空标签)
	var treeArrows:Array<FlxSprite> = []; // 展开指示三角(与 treeArrowButtons 一一对应)
	var selectedNode:ChartDirNode;
	var nodeByPath:Map<String, ChartDirNode> = new Map<String, ChartDirNode>();

	// ---- 右栏 ----
	var listButtons:Array<PsychUIButton> = [];
	var listButtonEntries:Array<ChartSourceEntry> = [];
	var listScroll:Float = 0;
	var searchedText:String = '';

	// ---- 目录扫描（数量统计逐帧分摊） ----
	var dirCache:Map<String, ChartDirListing> = new Map<String, ChartDirListing>();
	var scanQueue:Array<{node:ChartDirNode, depth:Int}> = [];
	static inline final SCANS_PER_FRAME:Int = 4;
	static inline final SCAN_DEPTH:Int = 3;

	public function new(?onSelectCallback:String->String->String->String->Void, ?onCancelCallback:Void->Void)
	{
		super();
		this.onSelect = onSelectCallback;
		this.onCancel = onCancelCallback;

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	override function create()
	{
		persistentUpdate = false; // 冻结父级（编辑器），避免弹窗期间网格仍响应滚轮
		persistentDraw = true;

		background = new FlxSprite().makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), FlxColor.BLACK);
		background.alpha = 0.6;
		background.scrollFactor.set();
		add(background);

		panel = new FlxSprite(80, 60).makeGraphic(Std.int(FlxG.width - 160), Std.int(FlxG.height - 120), FlxColor.fromString('0xFF1E1E1E'));
		panel.scrollFactor.set();
		add(panel);

		titleText = new FlxText(panel.x, panel.y + 6, panel.width, Language.getPhrase('chart_source_title', 'Select Chart Source'), 28);
		titleText.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER);
		titleText.scrollFactor.set();
		add(titleText);

		// 标题下方居中：Win10 风格沉浸式搜索框(placeholder 嵌在框内)
		var searchW:Float = 460;
		var searchH:Float = 32;
		searchBar = new Win10SearchBar(panel.x + (panel.width - searchW) / 2, panel.y + 46, searchW, searchH, 16);
		searchBar.setPlaceholder(Language.getPhrase('chart_source_search', 'Search') + '...');
		var hintCol:FlxColor = searchBar.hint.color;
		searchBar.hint.setFormat(Paths.font('vcr.ttf'), 16, hintCol, LEFT);
		searchBar.input.textObj.font = Paths.font('vcr.ttf');
		searchBar.scrollFactor.set();
		searchBar.onChange = function(oldText:String, newText:String)
		{
			if (searchedText == newText) return;
			searchedText = newText;
			resetPaneScroll(listScroller);
			refreshList();
			if (searchTerm().length > 0) enqueueCounts(selectedNode, SCAN_DEPTH); // 渐进填充子目录缓存供递归搜索
		};
		add(searchBar);

		// 声明本界面画在哪台相机上：鼠标命中判定（含 MouseMove 的拖拽基准）
		// 必须与面板布局同处一个坐标空间。FlxG.mouse.x/y 是游戏相机的世界坐标，
		// 会被 ChartingState 的网格滚动带着偏移，点击搜索框就会被误判成"点在框外"。
		OptionInput.bind(this, cameras[0]);
		uiCamera = cameras[0];

		// 两栏区域（左栏占面板宽度 20%）
		var panesTop:Float = panel.y + 120;
		var panesBottom:Float = panel.y + panel.height - 66;
		treeX = panel.x + 20;
		treeY = panesTop;
		treeW = Std.int(panel.width * 0.2);
		treeH = panesBottom - panesTop;
		listX = treeX + treeW + 16;
		listY = panesTop;
		listW = panel.x + panel.width - 20 - listX;
		listH = treeH;

		// 中间竖线：分隔目录树与文件列表
		divider = new FlxSprite(treeX + treeW + 7, panesTop).makeGraphic(2, Std.int(treeH), FlxColor.fromString('0xFF444444'));
		divider.scrollFactor.set();
		add(divider);

		// 底栏
		statusText = new FlxText(panel.x + 20, panel.y + panel.height - 46, 600, '', 18);
		statusText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.GRAY, LEFT);
		statusText.scrollFactor.set();
		add(statusText);

		cancelBtn = new PsychUIButton(panel.x + panel.width - 140, panel.y + panel.height - 52,
			Language.getPhrase('chart_source_cancel', 'Cancel'), function()
		{
			if (onCancel != null) onCancel();
			close();
		});
		cancelBtn.text.font = Paths.font('vcr.ttf');
		cancelBtn.text.size = 14;
		cancelBtn.resize(120, 32);
		cancelBtn.normalStyle.bgColor = FlxColor.RED;
		cancelBtn.normalStyle.textColor = FlxColor.WHITE;
		cancelBtn.scrollFactor.set();
		cancelBtn.cameras = [uiCamera];
		add(cancelBtn);

		buildTreeRoots();

		// 两栏各自的滚动控制器（初始树/列表在 buildTreeRoots 里已就位，这里只接管后续滚动）
		treeScroller = createPaneScroller('treeScroll', treeX, treeY, treeW, treeH, positionTreeRows);
		listScroller = createPaneScroller('listScroll', listX, listY, listW, listH, positionListRows);
		syncScrollLimit(treeScroller, maxTreeScroll());
		syncScrollLimit(listScroller, maxListScroll());
		add(treeScroller);
		add(listScroller);

		super.create();
	}

	override function destroy():Void
	{
		OptionInput.unbind(this);
		super.destroy();
	}

	// ================= 目录树 =================

	function buildTreeRoots():Void
	{
		#if sys
		ensureChartRoot();
		#end

		rootNode = new ChartDirNode('', '', -1, null);
		var contentNode:ChartDirNode = new ChartDirNode(Paths.CONTENT_ROOT, Language.getPhrase('chart_source_root_content', 'Content'), 0, rootNode);
		var assetsNode:ChartDirNode = new ChartDirNode(ROOT_ASSETS, 'Assets', 0, rootNode);
		var modsNode:ChartDirNode = new ChartDirNode(ROOT_MODS, 'Mods', 0, rootNode);
		rootNode.children = [contentNode, assetsNode, modsNode];
		rootNode.expanded = true;
		for (r in rootNode.children) registerNode(r);

		// 默认选中 Content
		navigateTo(contentNode);
	}

	function registerNode(node:ChartDirNode):Void
	{
		if (node.path.length > 0) nodeByPath.set(node.path.toLowerCase(), node);
	}

	/** 同步确保 children 已加载（只 readDirectory 一层） */
	function ensureChildren(node:ChartDirNode):Void
	{
		if (node.children != null) return;
		node.children = [];
		#if sys
		var listing:ChartDirListing = getListing(node.path);
		for (dir in listing.dirs)
		{
			var childPath:String = node.path + '/' + dir;
			if (!childVisible(childPath)) continue; // assets/mods 只保留 data 布局分支
			var child:ChartDirNode = new ChartDirNode(childPath, dir, node.depth + 1, node);
			node.children.push(child);
			registerNode(child);
		}
		#end
	}

	function toggleExpand(node:ChartDirNode):Void
	{
		if (clickVetoed(treeScroller)) return; // 拖拽/惯性甩尾的松开不算点击
		if (!node.expanded)
		{
			ensureChildren(node);
			enqueueCounts(node, SCAN_DEPTH);
		}
		node.expanded = !node.expanded;
		rebuildTree();
	}

	function navigateTo(node:ChartDirNode):Void
	{
		var p:ChartDirNode = node;
		while (p != null) { p.expanded = true; p = p.parent; }
		selectedNode = node;
		ensureChildren(node);
		enqueueCounts(node, SCAN_DEPTH);
		resetPaneScroll(treeScroller);
		resetPaneScroll(listScroller);
		rebuildTree();
		rebuildBreadcrumb();
		refreshList();
	}

	function flattenTree(node:ChartDirNode, rows:Array<ChartDirNode>):Void
	{
		if (node.depth >= 0) rows.push(node);
		if (node.expanded && node.children != null)
			for (c in node.children) flattenTree(c, rows);
	}

	function rebuildTree():Void
	{
		clearTreeButtons();
		treeRows = [];
		flattenTree(rootNode, treeRows);

		for (i in 0...treeRows.length)
		{
			var node:ChartDirNode = treeRows[i];
			var rowY:Float = rowTreeY(i);
			var baseX:Float = treeX + 6 + node.depth * 16;

			// 展开/收起箭头（无子目录时不显示）——空文本按钮做点击区，三角图标画在上面
			var hasArrow:Bool = node.children == null || node.children.length > 0;
			if (hasArrow)
			{
				var arrowBtn:PsychUIButton = new PsychUIButton(baseX, rowY, '', function() { toggleExpand(node); });
				arrowBtn.text.size = 8;
				arrowBtn.resize(22, ROW_H - 4);
				arrowBtn.normalStyle.bgColor = FlxColor.fromString('0xFF3A3A3A');
				arrowBtn.normalStyle.textColor = FlxColor.WHITE;
				arrowBtn.scrollFactor.set();
				arrowBtn.cameras = [uiCamera];
				add(arrowBtn);
				treeArrowButtons.push(arrowBtn);

				// 展开态换下指三角贴图而不是旋转贴图：旋转过的 sprite 裁剪不了
				var icon:FlxSprite = new FlxSprite(baseX + 6, rowY + 7);
				icon.loadGraphic(node.expanded ? getArrowDownGraphic() : getArrowGraphic());
				icon.color = 0xFFCCCCCC;
				icon.scrollFactor.set();
				icon.cameras = [uiCamera];
				add(icon);
				treeArrows.push(icon);
			}

			var nameX:Float = baseX + (hasArrow ? 24 : 2);
			var nameBtn:PsychUIButton = new PsychUIButton(nameX, rowY, treeLabel(node), function()
			{
				if (clickVetoed(treeScroller)) return;
				if (selectedNode != node) navigateTo(node);
			});
			nameBtn.text.font = Paths.font('vcr.ttf');
			nameBtn.text.size = 14;
			nameBtn.text.alignment = LEFT;
			nameBtn.resize(Std.int(Math.max(60, treeX + treeW - 10 - nameX)), ROW_H - 4);
			nameBtn.normalStyle.bgColor = (node == selectedNode) ? FlxColor.fromString('0xFF3B82F6') : FlxColor.fromString('0xFF2A2A2A');
			nameBtn.normalStyle.textColor = FlxColor.WHITE;
			nameBtn.scrollFactor.set();
			nameBtn.cameras = [uiCamera];
			add(nameBtn);
			treeButtons.push(nameBtn);
			treeButtonNodes.push(node);
		}

		positionTreeRows();
		syncScrollLimit(treeScroller, maxTreeScroll());
	}

	function treeLabel(node:ChartDirNode):String
	{
		var label:String = node.label;
		if (node.chartCount > 0) label += '  (' + node.chartCount + ')';
		return label;
	}

	// 展开指示三角贴图（收起=右指、展开=下指），各生成一次；不用 angle 旋转，方便边缘裁剪
	static var arrowGraphic:FlxGraphic = null;
	static var arrowDownGraphic:FlxGraphic = null;

	static function getArrowGraphic():FlxGraphic
	{
		if (arrowGraphic != null) return arrowGraphic;
		var spr:FlxSprite = new FlxSprite();
		spr.makeGraphic(10, 10, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawPolygon(spr, [FlxPoint.get(2, 1), FlxPoint.get(9, 5), FlxPoint.get(2, 9)], FlxColor.WHITE);
		arrowGraphic = spr.graphic;
		return arrowGraphic;
	}

	static function getArrowDownGraphic():FlxGraphic
	{
		if (arrowDownGraphic != null) return arrowDownGraphic;
		var spr:FlxSprite = new FlxSprite();
		spr.makeGraphic(10, 10, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawPolygon(spr, [FlxPoint.get(1, 2), FlxPoint.get(9, 2), FlxPoint.get(5, 9)], FlxColor.WHITE);
		arrowDownGraphic = spr.graphic;
		return arrowDownGraphic;
	}

	function rowTreeY(index:Int):Float
	{
		return treeY + 4 + index * ROW_H - treeScroll;
	}

	function positionTreeRows():Void
	{
		var arrowIndex:Int = 0;
		for (i in 0...treeRows.length)
		{
			var node:ChartDirNode = treeRows[i];
			var rowY:Float = rowTreeY(i);
			var baseX:Float = treeX + 6 + node.depth * 16;
			var hasArrow:Bool = node.children == null || node.children.length > 0;

			if (hasArrow)
			{
				var arrowBtn:PsychUIButton = treeArrowButtons[arrowIndex];
				arrowBtn.x = baseX;
				arrowBtn.y = rowY;
				applyRowClip(arrowBtn, treeX, treeY, treeW, treeH);

				var icon:FlxSprite = treeArrows[arrowIndex];
				icon.x = baseX + 6;
				icon.y = rowY + 7;
				applyRowClip(icon, treeX, treeY, treeW, treeH);
				arrowIndex++;
			}

			var nameX:Float = baseX + (hasArrow ? 24 : 2);
			var nameBtn:PsychUIButton = treeButtons[i];
			nameBtn.x = nameX;
			nameBtn.y = rowY;
			applyRowClip(nameBtn, treeX, treeY, treeW, treeH);
		}
	}

	/**
	 * 行与面板视口的三态处理：
	 * 整行在视口外不画不停更（组级 visible/active 会下发到成员）；整行在视口内清掉旧裁剪；
	 * 露出一截的裁到视口边缘。
	 * 裁剪必须 clipToViewBounds 显式传本界面相机：clipToWorldBounds 不收相机参数、内部取
	 * getDefaultCamera()，update 阶段（本函数的调用时机）解析到的是滚动的游戏相机而非
	 * camUI，clipRect 会整体偏 −scroll，与帧不相交时行直接被裁成空帧消失。
	 * PsychUIButton 这类 FlxSpriteGroup 不能对组整体裁：组的 initVars 不建 animation 控制器，
	 * 基类坐标换算链摸 animation.curAnim 必崩（flixel 6.2.0，git 版才有组级覆写），
	 * 逐成员裁——bg/text 都是真 FlxSprite，安全。详见 .agents/skills/flixel-clip。
	 */
	function applyRowClip(target:FlxSprite, paneX:Float, paneY:Float, paneW:Float, paneH:Float):Void
	{
		var fullyOutside:Bool = target.y + target.height <= paneY || target.y >= paneY + paneH;
		target.visible = !fullyOutside;
		target.active = !fullyOutside;

		var groupMembers:Array<FlxSprite> = null;
		var group:FlxSpriteGroup = Std.downcast(target, FlxSpriteGroup);
		if (group != null) groupMembers = group.members;

		var fullyInside:Bool = !fullyOutside && target.y >= paneY && target.y + target.height <= paneY + paneH;
		if (fullyOutside || fullyInside)
		{
			if (groupMembers != null)
			{
				for (m in groupMembers)
					if (m != null && m.clipRect != null) m.clipRect = null;
			}
			else if (target.clipRect != null) target.clipRect = null;
			return;
		}

		if (groupMembers != null)
		{
			for (m in groupMembers)
				if (m != null) m.clipToViewBounds(paneX, paneY, paneX + paneW, paneY + paneH, uiCamera);
		}
		else
		{
			target.clipToViewBounds(paneX, paneY, paneX + paneW, paneY + paneH, uiCamera);
		}
	}

	function clearTreeButtons():Void
	{
		// 只 remove 不 destroy:onClick 可能正跑在被点按钮自己的 update 里,
		// 销毁会让它返回 _updateStyle 时摸到已销毁的 text 而崩溃(交给状态销毁/GC 回收)。
		for (btn in treeButtons) remove(btn, true);
		for (btn in treeArrowButtons) remove(btn, true);
		for (icon in treeArrows) remove(icon, true);
		treeButtons = [];
		treeButtonNodes = [];
		treeArrowButtons = [];
		treeArrows = [];
	}

	function maxTreeScroll():Float
	{
		return Math.max(0, treeRows.length * ROW_H - treeH + 8);
	}

	function rebuildBreadcrumb():Void
	{
		for (btn in breadcrumbButtons) remove(btn, true);
		breadcrumbButtons = [];
		if (selectedNode == null) return;

		var chain:Array<ChartDirNode> = [];
		var node:ChartDirNode = selectedNode;
		while (node != null && node.depth >= 0) { chain.unshift(node); node = node.parent; }

		var bx:Float = panel.x + 20;
		var by:Float = panel.y + 84;
		var maxBX:Float = panel.x + panel.width - 20;
		for (i in 0...chain.length)
		{
			var seg:ChartDirNode = chain[i];
			var label:String = seg.label;
			if (label.length > 14) label = label.substring(0, 13) + '..';
			var width:Float = Std.int(Math.min(160, 26 + label.length * 9));
			if (bx + width > maxBX) break;

			var btn:PsychUIButton = new PsychUIButton(bx, by, label, function() { navigateTo(seg); });
			btn.text.font = Paths.font('vcr.ttf');
			btn.text.size = 13;
			btn.resize(Std.int(width), ROW_H - 4);
			btn.normalStyle.bgColor = (seg == selectedNode) ? FlxColor.fromString('0xFF3B82F6') : FlxColor.fromString('0xFF333333');
			btn.normalStyle.textColor = FlxColor.WHITE;
			btn.scrollFactor.set();
			btn.cameras = [uiCamera];
			add(btn);
			breadcrumbButtons.push(btn);
			bx += width + 8;
		}
	}

	// ================= 右栏列表 =================

	function searchTerm():String
	{
		return searchedText.toLowerCase().trim();
	}

	function refreshList():Void
	{
		for (btn in listButtons) remove(btn, true);
		listButtons = [];
		listButtonEntries = [];
		if (emptyText != null) { remove(emptyText, true); emptyText = null; }

		if (selectedNode == null) return;
		#if sys
		var entries:Array<ChartSourceEntry> = buildListEntries(selectedNode.path);
		#else
		var entries:Array<ChartSourceEntry> = [];
		#end

		var term:String = searchTerm();

		if (entries.length < 1)
		{
			var msg:String = (term.length > 0)
				? Language.getPhrase('chart_source_no_match', 'No results for "{1}".', [searchedText.trim()])
				: Language.getPhrase('chart_source_empty_dir', 'No chart files found in this folder.');
			emptyText = new FlxText(listX + 12, listY + 12, listW - 24, msg, 18);
			emptyText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.GRAY, LEFT);
			emptyText.scrollFactor.set();
			add(emptyText);
		}
		else
		{
			// 最多渲染 500 行，防止超大目录卡顿
			var truncated:Bool = entries.length > 500;
			var count:Int = truncated ? 500 : entries.length;
			for (i in 0...count)
			{
				var entry:ChartSourceEntry = entries[i];
				var displayLabel:String = (entry.type == 'directory') ? dirLabel(entry) : fileLabel(entry);
				if (displayLabel.length > 70) displayLabel = displayLabel.substring(0, 68) + '..';

				var rowY:Float = rowListY(i);
				var btn:PsychUIButton = new PsychUIButton(listX, rowY, displayLabel, makeListClickHandler(entry));
				btn.text.font = Paths.font('vcr.ttf');
				btn.text.size = 14;
				btn.text.alignment = LEFT;
				btn.resize(Std.int(listW - 8), ROW_H - 4);
				btn.normalStyle.bgColor = FlxColor.fromString('0xFF2F2F2F');
				btn.normalStyle.textColor = (entry.type == 'directory') ? FlxColor.WHITE : FlxColor.fromString('0xFFB8D8FF');
				btn.scrollFactor.set();
				btn.cameras = [uiCamera];
				add(btn);
				listButtons.push(btn);
				listButtonEntries.push(entry);
			}
			if (truncated)
				statusText.text = Language.getPhrase('chart_source_truncated', 'Showing 500 of {1} entries...', [entries.length]);
		}

		positionListRows();
		syncScrollLimit(listScroller, maxListScroll());
		if (term.length > 0)
			statusText.text = entries.length + ' results';
		else
			updateStatusText();
	}

	function makeListClickHandler(entry:ChartSourceEntry):Void->Void
	{
		return function()
		{
			if (clickVetoed(listScroller)) return; // 拖拽/惯性甩尾的松开不算点击
			if (entry.type == 'directory')
			{
				var key:String = entry.path.toLowerCase();
				var node:ChartDirNode = nodeByPath.get(key);
				if (node == null)
				{
					node = new ChartDirNode(entry.path, entry.label, selectedNode.depth + 1, selectedNode);
					registerNode(node);
				}
				navigateTo(node);
			}
			else onFilePicked(entry);
		};
	}

	function dirLabel(entry:ChartSourceEntry):String
	{
		var label:String = '📁 ' + entry.label;
		var node:ChartDirNode = nodeByPath.get(entry.path.toLowerCase());
		if (node != null && node.chartCount > 0) label += '  (' + node.chartCount + ')';
		return label;
	}

	function fileLabel(entry:ChartSourceEntry):String
	{
		return '📄 ' + entry.label;
	}

	function buildListEntries(dir:String):Array<ChartSourceEntry>
	{
		var entries:Array<ChartSourceEntry> = [];
		var listing:ChartDirListing = getListing(dir);
		var term:String = searchTerm();

		if (term.length < 1)
		{
			for (d in listing.dirs)
			{
				var childPath:String = dir + '/' + d;
				if (!childVisible(childPath)) continue;
				entries.push({label: d, path: childPath, category: null, variant: null, type: 'directory', name: d});
			}
			for (f in listing.chartFiles)
			{
				if (!childVisible(f.path)) continue;
				entries.push(f);
			}
			return entries;
		}

		// 搜索模式：当前目录的直接匹配 + 递归(受限深度)匹配谱面文件
		for (d in listing.dirs)
		{
			if (d.toLowerCase().indexOf(term) == -1) continue;
			var childPath:String = dir + '/' + d;
			if (!childVisible(childPath)) continue;
			entries.push({label: d, path: childPath, category: null, variant: null, type: 'directory', name: d});
		}
		for (f in listing.chartFiles)
		{
			if (!childVisible(f.path)) continue;
			if (f.name.toLowerCase().indexOf(term) != -1 || f.label.toLowerCase().indexOf(term) != -1)
				entries.push(f);
		}

		var seen:Map<String, Bool> = new Map<String, Bool>();
		for (e in entries) seen.set(e.path.toLowerCase(), true);
		collectSearchMatches(dir, dir, term, SCAN_DEPTH, entries, seen);
		return entries;
	}

	function collectSearchMatches(rootDir:String, dir:String, term:String, depthLeft:Int, out:Array<ChartSourceEntry>, seen:Map<String, Bool>):Void
	{
		if (depthLeft < 1) return;
		var listing:ChartDirListing = dirCache.get(dir);
		if (listing == null) return; // 未扫描到的目录等扫描队列填充后会自动刷新

		for (sub in listing.dirs)
		{
			var subPath:String = dir + '/' + sub;
			if (!childVisible(subPath)) continue; // assets/mods 只搜 data 布局分支
			var subListing:ChartDirListing = dirCache.get(subPath);
			var matchedDir:Bool = sub.toLowerCase().indexOf(term) != -1;

			if (subListing != null)
			{
				for (f in subListing.chartFiles)
				{
					if (!childVisible(f.path)) continue;
					var key:String = f.path.toLowerCase();
					if (seen.exists(key)) continue;
					if (f.name.toLowerCase().indexOf(term) != -1 || matchedDir)
					{
						seen.set(key, true);
						var rel:String = f.path.substring(rootDir.length + 1);
						out.push({label: rel, path: f.path, category: null, variant: f.variant, type: 'file', name: f.name});
					}
				}
			}
			collectSearchMatches(rootDir, subPath, term, depthLeft - 1, out, seen);
		}
	}

	function rowListY(index:Int):Float
	{
		return listY + 4 + index * ROW_H - listScroll;
	}

	function positionListRows():Void
	{
		for (i in 0...listButtons.length)
		{
			var btn:PsychUIButton = listButtons[i];
			btn.y = rowListY(i);
			applyRowClip(btn, listX, listY, listW, listH);
		}
	}

	function maxListScroll():Float
	{
		return Math.max(0, listButtons.length * ROW_H - listH + 8);
	}

	// ================= 滚动控制器 =================

	/** 单栏滚动控制器：拖拽 + 惯性 + 滚轮，命中区域限制在本栏矩形内。 */
	function createPaneScroller(prop:String, px:Float, py:Float, pw:Float, ph:Float, onScroll:Void->Void):MouseMove
	{
		var scroller:MouseMove = new MouseMove(this, prop, [0, 0], [[px, px + pw], [py, py + ph]], onScroll);
		scroller.useViewSpace = true; // 用绑定相机后的视图空间，跟面板布局同一坐标系
		scroller.useLerp = true;
		scroller.lerpSmooth = 12;
		scroller.deceleration = 0.94;
		scroller.mouseWheelSensitivity = -320; // 一格滚轮约滚 3 行
		return scroller;
	}

	/** 行数变化后同步滚动上限（MouseMove 会自己把越界的滚动 lerp 回来）。 */
	function syncScrollLimit(scroller:MouseMove, maxScroll:Float):Void
	{
		if (scroller != null) scroller.moveLimit[1] = maxScroll;
	}

	/** 回到顶部（走 tweenData 让 MouseMove 自己 lerp 过去，同时清掉拖拽残留输入）。 */
	function resetPaneScroll(scroller:MouseMove):Void
	{
		if (scroller == null) return;
		scroller.resetInputState();
		scroller.tweenData = 0;
	}

	/**
	 * 行按钮点击是否应被忽略：按下后指针明显移动过（真拖拽、慢速拖拽的松开），
	 * 或按下期间本栏实际滚动过（惯性/滚轮把行从指针底下带走了）。
	 * 不看 MouseMove 的 isDragging/state：滚轮一格的惯性尾巴按 0.94/帧衰减要约 3 秒
	 * 才落到阈值，按住 100ms 不动也会被判进拖拽——拿它们否决会把正常点击整个吞掉
	 * （刚滚完就点的边缘行、按得慢一点的点击全部失灵）。
	 */
	function clickVetoed(scroller:MouseMove):Bool
	{
		if (pressTracked && Math.abs(OptionInput.mouseY() - pressY) > 8) return true;
		if (scroller == null) return false;
		var pressScroll:Float = (scroller == treeScroller) ? pressTreeScroll : pressListScroll;
		return Math.abs(scroller.target - pressScroll) > 2;
	}

	function updateStatusText():Void
	{
		#if sys
		if (searchTerm().length > 0) return; // 搜索时 statusText 可能被截断提示占用
		var listing:ChartDirListing = getListing(selectedNode.path);
		var total:Int = selectedNode.chartCount;
		var visibleDirs:Int = 0;
		for (d in listing.dirs)
			if (childVisible(selectedNode.path + '/' + d)) visibleDirs++;
		statusText.text = visibleDirs + ' folders, ' + listing.chartFiles.length + ' charts here, ' + total + ' charts below';
		#end
	}

	// ================= 选择与分发 =================

	function onFilePicked(entry:ChartSourceEntry):Void
	{
		#if sys
		// V-Slice 图谱：chart 命名 + 同目录存在 metadata → 选难度
		if (isVSliceChartFileName(entry.name))
		{
			var folder:String = entry.path.substring(0, entry.path.lastIndexOf('/'));
			var listing:ChartDirListing = getListing(folder);
			if (listingHasMetadata(listing))
			{
				showDifficultySelectionFor(entry, folder, listing);
				return;
			}
		}
		#end
		dispatchEntry(entry, null);
	}

	function dispatchEntry(entry:ChartSourceEntry, ?difficulty:String):Void
	{
		var category:String = (difficulty != null) ? V_SLICE : resolveCategory(entry.path);
		close();
		if (onSelect != null) onSelect(category, entry.path, difficulty, entry.variant);
	}

	/**
	 * 回调的 category 语义：
	 * - content/CustomCharts 下：取根下的第一段目录名（v_slice 等），与旧版一致；
	 * - assets / mods 下：返回 'assets' / 'mods'，由 ChartingState 设置对应音频上下文。
	 */
	public static function resolveCategory(path:String):String
	{
		var p:String = path.replace('\\', '/');
		if (p == chartRoot) return null;
		if (p.startsWith(chartRoot + '/'))
		{
			var rest:String = p.substring(chartRoot.length + 1);
			var slash:Int = rest.indexOf('/');
			return (slash > 0) ? rest.substring(0, slash) : null;
		}
		if (p == ROOT_ASSETS || p.startsWith(ROOT_ASSETS + '/')) return ROOT_ASSETS;
		if (p == ROOT_MODS || p.startsWith(ROOT_MODS + '/')) return ROOT_MODS;
		return null;
	}

	#if sys
	function showDifficultySelectionFor(entry:ChartSourceEntry, folder:String, listing:ChartDirListing):Void
	{
		var metadataPath:String = null;
		for (file in listing.rawFiles)
		{
			var lower:String = file.toLowerCase();
			if (lower.indexOf('metadata') != -1 && lower.endsWith('.json'))
			{
				metadataPath = folder + '/' + file;
				break;
			}
		}
		if (metadataPath == null) { dispatchEntry(entry, null); return; }

		var diffs:Array<String> = null;
		try
		{
			var metadata:Dynamic = Json.parse(File.getContent(metadataPath));
			if (metadata != null && metadata.playData != null && metadata.playData.difficulties != null)
				diffs = cast metadata.playData.difficulties;
		}
		catch (e:Dynamic) diffs = null;

		if (diffs == null || diffs.length < 1) { dispatchEntry(entry, null); return; }

		var displayDiffs:Array<String> = getChartDifficulties(entry.path, diffs);
		if (displayDiffs.length < 1) displayDiffs = diffs;

		var selectedVariant:String = entry.variant;
		var sub:MusicBeatSubstate = new VSliceDifficultySelectSubstate(displayDiffs, function(selectedDiff:String)
		{
			close();
			if (onSelect != null) onSelect(V_SLICE, entry.path, selectedDiff, selectedVariant);
		}, null);
		// 弹层会暂停本界面更新，先清掉挂起的拖拽输入，免得恢复时误判成"开始拖拽"（不动滚动位置）
		if (treeScroller != null) treeScroller.resetInputState();
		if (listScroller != null) listScroller.resetInputState();
		openSubState(sub);
	}

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

	// ================= 目录扫描 =================

	static var dataBranchCache:Map<String, Bool> = new Map<String, Bool>();

	static function rootKindOf(path:String):String
	{
		var p:String = path.replace('\\', '/');
		if (p == Paths.CONTENT_ROOT || p.startsWith(Paths.CONTENT_ROOT + '/')) return 'content';
		if (p == ROOT_ASSETS || p.startsWith(ROOT_ASSETS + '/')) return ROOT_ASSETS;
		if (p == ROOT_MODS || p.startsWith(ROOT_MODS + '/')) return ROOT_MODS;
		return null;
	}

	static function pathHasDataSegment(path:String):Bool
	{
		for (seg in path.replace('\\', '/').split('/'))
			if (seg.toLowerCase() == 'data') return true;
		return false;
	}

	/**
	 * 目录树的过滤标准:
	 * - assets/mods：谱面只认 <xx>/data/<xx> 布局，深度 1 前瞻；
	 * - content/CustomCharts：分类目录本身就是谱面目录（<category>/<song>/chart.json，无 data 层），放行；
	 * - content 下其他内容包（VanillaSongs 等）：谱面在 <pack>/shared/data/<song>/，同样按
	 *   data 布局过滤，前瞻加深到 3 层（pack → shared → data）。没有谱面分支的目录
	 *   （NMVMODS、weeks/images 等纯资源夹）整体隐藏。
	 */
	function childVisible(path:String):Bool
	{
		var kind:String = rootKindOf(path);
		if (kind == ROOT_ASSETS || kind == ROOT_MODS)
		{
			if (pathHasDataSegment(path)) return true;
			return hasDataDescendant(path, 1);
		}
		if (kind == 'content')
		{
			if (path == Paths.CHART_ROOT || path.startsWith(Paths.CHART_ROOT + '/')) return true;
			if (pathHasDataSegment(path)) return true;
			return hasDataDescendant(path, 3);
		}
		return true;
	}

	/** 子目录里（depth 层内）是否出现 data 目录；结果按「深度|路径」缓存。 */
	function hasDataDescendant(path:String, depth:Int):Bool
	{
		if (depth < 1) return false;
		var key:String = depth + '|' + path.toLowerCase();
		if (dataBranchCache.exists(key)) return dataBranchCache.get(key);
		var result:Bool = false;
		#if sys
		var listing:ChartDirListing = getListing(path);
		for (d in listing.dirs)
		{
			if (d.toLowerCase() == 'data') { result = true; break; }
			if (depth > 1 && hasDataDescendant(path + '/' + d, depth - 1)) { result = true; break; }
		}
		#end
		dataBranchCache.set(key, result);
		return result;
	}

	function getListing(dir:String):ChartDirListing
	{
		var cached:ChartDirListing = dirCache.get(dir);
		if (cached != null) return cached;

		var listing:ChartDirListing = {dirs: [], chartFiles: [], rawFiles: []};
		#if sys
		try
		{
			if (FileSystem.exists(dir) && FileSystem.isDirectory(dir))
			{
				var hasMetadata:Bool = false;
				var raw:Array<String> = FileSystem.readDirectory(dir);
				for (item in raw)
				{
					if (item.startsWith('.')) continue;
					listing.rawFiles.push(item);
					var lower:String = item.toLowerCase();
					if (!hasMetadata && lower.indexOf('metadata') != -1 && lower.endsWith('.json')) hasMetadata = true;
				}
				for (item in raw)
				{
					if (item.startsWith('.')) continue;
					var child:String = dir + '/' + item;
					if (FileSystem.isDirectory(child)) listing.dirs.push(item);
					else if (CustomChartData.isChartFile(item))
					{
						// vanilla 包的命名（<歌>-metadata-<变体>.json / events-<变体>.json）
						// 不在 isChartFile 的全词忽略表里，按子串/前缀兜底过滤
						var fileLower:String = item.toLowerCase();
						if (fileLower.indexOf('metadata') != -1) continue;
						var fileStem:String = fileLower.substring(0, fileLower.lastIndexOf('.'));
						if (fileStem == 'events' || fileStem.startsWith('events-')) continue;

						var label:String = item;
						var variant:String = null;
						if (isVSliceChartFileName(item) && hasMetadata)
						{
							variant = getVariantNameFromFile(item);
							label = (variant == 'default') ? 'Default' : variant.charAt(0).toUpperCase() + variant.substr(1);
							label += '  [V-Slice]';
						}
						listing.chartFiles.push({label: label, path: child, category: null, variant: variant, type: 'file', name: item});
					}
				}
				listing.dirs.sort(sortCI);
				listing.chartFiles.sort(function(a:ChartSourceEntry, b:ChartSourceEntry) return sortCompareCI(a.label, b.label));
			}
		}
		catch (e:Dynamic) {}
		#end
		dirCache.set(dir, listing);
		return listing;
	}

	static function sortCI(a:String, b:String):Int
	{
		return sortCompareCI(a, b);
	}

	static function sortCompareCI(a:String, b:String):Int
	{
		var la:String = a.toLowerCase();
		var lb:String = b.toLowerCase();
		return la < lb ? -1 : (la > lb ? 1 : 0);
	}

	function listingHasMetadata(listing:ChartDirListing):Bool
	{
		for (file in listing.rawFiles)
		{
			var lower:String = file.toLowerCase();
			if (lower.indexOf('metadata') != -1 && lower.endsWith('.json')) return true;
		}
		return false;
	}

	/** 把节点及其子孙（限深）排进扫描队列，逐帧分摊 readDirectory 开销，用于谱面数量徽标与递归搜索。 */
	function enqueueCounts(node:ChartDirNode, depth:Int):Void
	{
		if (node == null || node.path.length < 1 || node.queued) return;
		node.queued = true;
		scanQueue.push({node: node, depth: depth});
	}

	function processScanQueue():Bool
	{
		var changed:Bool = false;
		#if sys
		for (_ in 0...SCANS_PER_FRAME)
		{
			if (scanQueue.length < 1) break;
			var job = scanQueue.shift();
			job.node.queued = false;
			if (!FileSystem.exists(job.node.path) || !FileSystem.isDirectory(job.node.path))
			{
				job.node.ownCount = 0;
				changed = true;
				continue;
			}
			var listing:ChartDirListing = getListing(job.node.path);
			ensureChildren(job.node);
			job.node.ownCount = listing.chartFiles.length;
			if (job.depth > 1)
				for (c in job.node.children) enqueueCounts(c, job.depth - 1);
			changed = true;
		}
		#end
		return changed;
	}

	function refreshCounts(node:ChartDirNode):Int
	{
		var total:Int = node.ownCount;
		if (node.children != null)
			for (c in node.children) total += refreshCounts(c);
		node.chartCount = total;
		return total;
	}

	/** 扫描有进展后刷新可见行的数量徽标（只在文本变化时重设，避免每帧重排文本）。 */
	function refreshBadges():Void
	{
		for (i in 0...treeButtons.length)
		{
			var node:ChartDirNode = treeButtonNodes[i];
			var label:String = treeLabel(node);
			if (treeButtons[i].text.text != label) treeButtons[i].text.text = label;
		}
		for (i in 0...listButtons.length)
		{
			var entry:ChartSourceEntry = listButtonEntries[i];
			if (entry.type != 'directory') continue;
			var label:String = dirLabel(entry);
			if (label.length > 70) label = label.substring(0, 68) + '..';
			if (listButtons[i].text.text != label) listButtons[i].text.text = label;
		}
		updateStatusText();
	}

	// ================= 其他 =================

	/** 谱面路径所属的 VanillaSongs 内容包根（content/VanillaSongs/<pack>）；不在该体系下返回 null。 */
	public static function vanillaPackRootOf(path:String):String
	{
		var p:String = path.replace('\\', '/');
		var prefix:String = Paths.CONTENT_ROOT + '/' + VANILLA_PACKS + '/';
		if (!p.startsWith(prefix)) return null;
		var rest:String = p.substring(prefix.length);
		if (rest.length < 1) return null;
		var slash:Int = rest.indexOf('/');
		return prefix + ((slash > 0) ? rest.substring(0, slash) : rest);
	}

	/**
	 * 从谱面文件名推内容包变体（Erect / Pico / BF…）。
	 * PicoMix/BFMix 的周定义里写了 variant，setContentRoot 能自动反查；
	 * Erect 包的周没写（erect/nightmare 共用一套 Erect 音轨），只能靠文件名兜底。
	 * 变体目录名大小写与磁盘一致（songs/<歌>-Erect），findCaseInsensitiveDirectory 兜大小写。
	 */
	public static function vanillaVariantOf(path:String):String
	{
		var stem:String = path.replace('\\', '/');
		var slash:Int = stem.lastIndexOf('/');
		stem = (slash >= 0) ? stem.substring(slash + 1) : stem;
		var dot:Int = stem.lastIndexOf('.');
		if (dot > 0) stem = stem.substring(0, dot);
		stem = stem.toLowerCase();
		if (stem.endsWith('-erect') || stem.endsWith('-nightmare')) return 'Erect';
		if (stem.endsWith('-pico') || stem.indexOf('-pico-') != -1) return 'Pico';
		if (stem.endsWith('-bf') || stem.indexOf('-bf-') != -1) return 'BF';
		return null;
	}

	static function isVSliceChartFileName(fileName:String):Bool
	{
		var lower:String = fileName.toLowerCase();
		return lower == 'chart.json' || lower.indexOf('chart-') != -1 || lower.indexOf('_chart') != -1 || lower.indexOf('-chart') != -1;
	}

	static function getCategoryTitle(category:String):String
	{
		return switch (category)
		{
			case 'fnf': 'FNF';
			case V_SLICE: 'V-Slice';
			case 'osu_mania': 'Osu Mania';
			default: category;
		}
	}

	static function ensureChartRoot():Void
	{
		#if sys
		createDirectoryRecursive(chartRoot);
		for (cat in categories)
			createDirectoryRecursive('$chartRoot/$cat');
		#end
	}

	#if sys
	static function createDirectoryRecursive(path:String):Void
	{
		if (FileSystem.exists(path)) return;

		var parent:String = path.substring(0, path.lastIndexOf('/'));
		if (parent != '' && !FileSystem.exists(parent))
			createDirectoryRecursive(parent);

		try { FileSystem.createDirectory(path); } catch (e:Dynamic) {}
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

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// 记录按下起点的指针 Y 和两栏滚动位置（在成员处理过本帧输入之后仍是当帧值；
		// release 帧的 onClick 读到的基准恰好来自自己的 press 帧）
		if (FlxG.mouse.justPressed)
		{
			pressY = OptionInput.mouseY();
			pressTracked = true;
			pressTreeScroll = (treeScroller != null) ? treeScroller.target : 0;
			pressListScroll = (listScroller != null) ? listScroller.target : 0;
		}

		// 扫描队列分帧处理；有进展时刷新徽标（搜索模式下同时刷新结果列表）
		if (processScanQueue())
		{
			refreshCounts(rootNode);
			refreshBadges();
			if (searchTerm().length > 0) refreshList();
		}

		var searchFocused:Bool = (PsychUIInputText.focusOn == searchBar.input);

		// 点击搜索框外取消输入焦点（OptionInput.mouseX/Y 是绑定相机后的视图坐标；
		// FlxG.mouse.x/y 会被 ChartingState 游戏相机的滚动带偏，导致点框内也被判成框外）
		if (searchFocused && FlxG.mouse.justPressed)
		{
			var mx:Float = OptionInput.mouseX();
			var my:Float = OptionInput.mouseY();
			if (mx < searchBar.x || mx > searchBar.x + searchBar.width || my < searchBar.y - 4 || my > searchBar.y + searchBar.height + 4)
				PsychUIInputText.focusOn = null;
		}

		if (!searchFocused && FlxG.keys.justPressed.ESCAPE)
		{
			if (onCancel != null) onCancel();
			close();
		}
	}
}

/**
 * 目录树节点。children 为 null 表示尚未扫描；ownCount 是本目录直属谱面数，
 * chartCount 是 ownCount + 所有已扫描子孙的聚合数（由扫描队列逐步填充）。
 */
class ChartDirNode
{
	public var path:String;
	public var label:String;
	public var depth:Int;
	public var parent:ChartDirNode;
	public var children:Array<ChartDirNode> = null;
	public var expanded:Bool = false;
	public var ownCount:Int = 0;
	public var chartCount:Int = 0;
	public var queued:Bool = false;

	public function new(path:String, label:String, depth:Int, ?parent:ChartDirNode)
	{
		this.path = path;
		this.label = label;
		this.depth = depth;
		this.parent = parent;
	}
}

typedef ChartDirListing =
{
	var dirs:Array<String>;
	var chartFiles:Array<ChartSourceEntry>;
	var rawFiles:Array<String>;
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
		confirmBtn.text.font = Paths.font('vcr.ttf');
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
		cancelBtn.text.font = Paths.font('vcr.ttf');
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
