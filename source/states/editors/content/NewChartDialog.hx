package states.editors.content;

import flash.net.FileFilter;
import flixel.FlxBasic;
import flixel.group.FlxSpriteGroup;
import states.editors.content.Prompt.BasePrompt;

/**
 * 新建谱面向导回报的参数。
 */
typedef NewChartRequest =
{
	var kind:String; // 'custom' | 'mod'
	var songName:String;
	var bpm:Float;
	var mod:String;          // kind=='mod' 时的模组目录名
	var weekPath:String;     // kind=='mod' 时选中的 week.json 路径，空串表示不选
}

/**
 * 新建谱面对话框：选存放类型（custom / mod）、填歌名与 BPM。
 * mod 分支再从游戏内有效模组里选一个，并可选挑一个 week.json。
 * 音频不在这里选，落地阶段统一交给 ChartAudioImportWizard。
 */
class NewChartDialog extends BasePrompt
{
	var onDone:NewChartRequest->Void;

	var kindDrop:Win8DropDown;
	var songInput:PsychUIInputText;
	var bpmInput:PsychUIInputText;
	var modDrop:Win8DropDown;
	var weekPathText:FlxText;
	var errText:FlxText;

	var modElements:Array<FlxBasic> = [];
	var clickables:Array<FlxBasic> = [];
	var dropdowns:Array<Win8DropDown> = [];
	var topLayer:FlxSpriteGroup;
	var modActive:Bool = false;
	var selectedWeek:String = '';
	var fileDialog:FileDialogHandler;

	public function new(onDone:NewChartRequest->Void)
	{
		this.onDone = onDone;
		super(560, 460, 'New Chart', build);
	}

	function label(x:Float, y:Float, w:Float, text:String):FlxText
	{
		var t:FlxText = new FlxText(x, y, w, text, 16);
		t.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT);
		t.antialiasing = ClientPrefs.data.antialiasing;
		t.cameras = cameras;
		return t;
	}

	function setModVisible(v:Bool)
	{
		modActive = v;
		for (el in modElements)
		{
			el.visible = v;
			el.active = v;
		}
		modDrop.visible = v;
	}

	function build(state:BasePrompt)
	{
		var bx:Float = state.bg.x;
		var by:Float = state.bg.y;

		var hint:FlxText = label(bx + 30, by + 68, 500, 'Create a new song and open it in the chart editor.');
		hint.color = 0xFFAAAAAA;
		add(hint);

		add(label(bx + 30, by + 108, 130, 'Location:'));
		kindDrop = new Win8DropDown(bx + 160, by + 104, 220, ['Custom Chart', 'Mod'], function(idx:Int, val:String)
		{
			setModVisible(idx == 1);
		});
		kindDrop.cameras = cameras;
		add(kindDrop);
		dropdowns.push(kindDrop);

		add(label(bx + 30, by + 158, 130, 'Song Name:'));
		songInput = new PsychUIInputText(bx + 160, by + 152, 340, '', 12);
		songInput.cameras = cameras;
		add(songInput);
		clickables.push(songInput);

		add(label(bx + 30, by + 202, 130, 'BPM:'));
		bpmInput = new PsychUIInputText(bx + 160, by + 196, 120, '150', 12);
		bpmInput.cameras = cameras;
		add(bpmInput);
		clickables.push(bpmInput);

		var modNames:Array<String> = Mods.getModDirectories();
		if (modNames == null || modNames.length < 1) modNames = ['(no mods found)'];

		var modLabel:FlxText = label(bx + 30, by + 254, 130, 'Mod:');
		add(modLabel);
		modElements.push(modLabel);

		modDrop = new Win8DropDown(bx + 160, by + 250, 220, modNames);
		modDrop.cameras = cameras;
		add(modDrop);
		dropdowns.push(modDrop);

		var weekLabel:FlxText = label(bx + 30, by + 300, 130, 'Week JSON:');
		add(weekLabel);
		modElements.push(weekLabel);

		var weekBtn:PsychUIButton = new PsychUIButton(bx + 160, by + 296, 'Select week.json... (optional)', function()
		{
			if (!fileDialog.completed) return;
			fileDialog.open(null, 'Select a week.json (optional)', [new FileFilter('Week JSON', '*.json')], function()
			{
				selectedWeek = (fileDialog.path == null) ? '' : StringTools.replace(fileDialog.path, '\\', '/');
				weekPathText.text = (selectedWeek.length > 0) ? selectedWeek : '(none - not added to any week)';
				errText.text = '';
			}, function() {}, function() {}); // onCancel/onError 都传非 null：handler 的 onCancel 实现有坑
		}, 220, 28);
		weekBtn.cameras = cameras;
		add(weekBtn);
		modElements.push(weekBtn);

		weekPathText = label(bx + 160, by + 330, 400, '(none - not added to any week)');
		weekPathText.color = 0xFFAAAAAA;
		add(weekPathText);
		modElements.push(weekPathText);

		errText = label(bx + 30, by + 372, 500, '');
		errText.color = 0xFFFF6B6B;
		add(errText);

		var createBtn:PsychUIButton = new PsychUIButton(bx + 160, by + 408, 'Create', function()
		{
			if (tryCreate()) close();
		}, 170, 32);
		createBtn.normalStyle.bgColor = FlxColor.GREEN;
		createBtn.normalStyle.textColor = FlxColor.WHITE;
		createBtn.cameras = cameras;
		add(createBtn);
		clickables.push(createBtn);

		var cancelBtn:PsychUIButton = new PsychUIButton(bx + 350, by + 408, 'Cancel', close, 120, 32);
		cancelBtn.cameras = cameras;
		add(cancelBtn);
		clickables.push(cancelBtn);

		#if sys
		fileDialog = new FileDialogHandler();
		#end

		// 下拉弹层挂到最后的容器上，否则展开时会被后加的按钮盖住
		topLayer = new FlxSpriteGroup();
		topLayer.scrollFactor.set();
		topLayer.cameras = cameras;
		state.add(topLayer);
		for (dd in dropdowns) dd.attachPopup(topLayer, cameras[0]);

		setModVisible(false);
	}

	override function update(elapsed:Float)
	{
		// 任一下拉展开时挂起其它交互组件，防止点击穿透到弹层下方的按钮
		var openDD:Win8DropDown = null;
		for (dd in dropdowns)
			if (dd.isOpen) { openDD = dd; break; }

		for (dd in dropdowns)
		{
			var shouldBeActive:Bool = (dd == modDrop ? modActive : true) && (openDD == null || dd == openDD);
			if (dd.active != shouldBeActive)
			{
				dd.active = shouldBeActive;
				if (!shouldBeActive) dd.clearInputState();
			}
		}
		for (el in modElements) el.active = modActive && (openDD == null);
		for (c in clickables) if (c != null) c.active = (openDD == null);

		super.update(elapsed);
	}

	function tryCreate():Bool
	{
		errText.text = '';

		var name:String = (songInput.text == null) ? '' : StringTools.trim(songInput.text);
		if (name.length < 1)
		{
			errText.text = 'Please enter a song name.';
			return false;
		}

		var bpm:Float = Std.parseFloat(bpmInput.text);
		if (Math.isNaN(bpm) || bpm <= 0)
		{
			errText.text = 'Please enter a valid BPM (greater than 0).';
			return false;
		}

		var isMod:Bool = (kindDrop.selectedIndex == 1);
		var mod:String = '';
		var week:String = '';
		if (isMod)
		{
			var names:Array<String> = Mods.getModDirectories();
			if (names == null || names.length < 1 || modDrop.selectedIndex < 0 || modDrop.selectedIndex >= names.length)
			{
				errText.text = 'No valid mod selected.';
				return false;
			}
			mod = names[modDrop.selectedIndex];
			week = selectedWeek;
		}

		if (onDone != null)
			onDone({kind: isMod ? 'mod' : 'custom', songName: name, bpm: bpm, mod: mod, weekPath: week});
		return true;
	}

	override function destroy()
	{
		if (fileDialog != null)
		{
			fileDialog.destroy();
			fileDialog = null;
		}
		super.destroy();
	}
}
