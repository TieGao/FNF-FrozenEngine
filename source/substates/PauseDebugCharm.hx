package substates;

import options.Option;
import options.Option.OptionType;
import options.Win8CharmSettings;
import options.Win8CharmSettings.CharmEntry;
import options.Win8CharmSettings.CharmOption;
import options.Win8CharmSettings.CharmActionOption;

import backend.UIControlTheme;

import flixel.util.FlxStringUtil;

/**
 * ==========================================================================
 * PauseDebugCharm —— 暂停菜单的 Tool 浮出层
 * ==========================================================================
 
 */
class PauseDebugCharm extends Win8CharmSettings
{
	var host:NewPauseSubState;
	var debugKeys:Array<String> = [];
	var curTime:Float = 0;
	var aborted:Bool = false;

	public function new(host:NewPauseSubState)
	{
		super();

		this.host = host;
		initDebugKeys();
		curTime = Math.max(0, Conductor.songPosition);
		dismissOnOutsideClick = true;

		// 动作行（Skip to Time / Leave Charting Mode / End Song）用大按钮。
		// 工厂默认的 100×35 太小，跟上方 Skip Time 的数值条宽度对不齐，看着零碎。
		largeActionButtons = true;
	}

	override function create()
	{

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		FlxG.camera.followLerp = 0;
		if (debugKeys.length == 0)
		{
			prevSurface = UIControlTheme.current();
			aborted = true;
			close();
			return;
		}

		super.create();
	}

	override function update(elapsed:Float)
	{
		if (aborted) return;
		super.update(elapsed);
	}

	// =========================================================
	// 面板内容
	// =========================================================
	override public function buildCharms():Array<CharmEntry>
	{
		var opts:Array<Option> = buildDebugOptions();
		if (opts.length == 0) return [];

		return [{
			id: 'tool',
			title: 'Debug',
			description: 'Debug tools for charting, practice and botplay',
			options: opts
		}];
	}

	/** 面板顶部大标题。基类默认取第一个分组的标题，会和分组小标题撞车，所以自己给一个。 */
	override public function getPageTitle():String
	{
		return Language.getPhrase("charting_panel", "Charting Panel");
	}

	override public function closeCharmBar():Void
	{
		FlxG.mouse.visible = true;
		close();
	}

	// =========================================================
	// 条目集合（= 旧 NewPauseSubState.initDebugOptions()，逻辑一字不改）
	// =========================================================
	function initDebugKeys():Void
	{
		if (PlayState.chartingMode)
		{
			debugKeys = ['pause_skip_time', 'pause_toggle_practice_mode', 'pause_toggle_botplay',
				'pause_leave_charting_mode', 'pause_end_song'];
		}
		else if (PlayState.instance.practiceMode || PlayState.instance.cpuControlled)
		{
			debugKeys = [];
			if (PlayState.instance.practiceMode) debugKeys.push('pause_toggle_practice_mode');
			if (PlayState.instance.cpuControlled) debugKeys.push('pause_toggle_botplay');
			debugKeys.push('pause_skip_time');
		}
		else
		{
			debugKeys = [];
		}
	}

	function buildDebugOptions():Array<Option>
	{
		var out:Array<Option> = [];

		for (key in debugKeys)
		{
			switch (key)
			{
				case 'pause_skip_time':
					out.push(makeSkipTimeOption());
					out.push(makeSkipActionOption());

				case 'pause_toggle_practice_mode':
					out.push(makePracticeOption());

				case 'pause_toggle_botplay':
					out.push(makeBotplayOption());

				case 'pause_leave_charting_mode':
					var leave:Option = new CharmActionOption(
						Language.getPhrase('pause_leave_charting_mode', 'Leave Charting Mode'),
						'Turn charting mode off and restart the song',
						Language.getPhrase('options.action.open', 'Open'));
					leave.action = function() {
						PlayState.chartingMode = false;
						if (host != null) host.restartSong();
					};
					out.push(leave);

				case 'pause_end_song':
					var end:Option = new CharmActionOption(
						Language.getPhrase('pause_end_song', 'End Song'),
						'Jump straight to the results screen',
						Language.getPhrase('options.action.open', 'Open'));
					end.action = function() { runHostAction(function() { if (host != null) host.endSong(); }); };
					out.push(end);
			}
		}

		return out;
	}

	function makeSkipTimeOption():Option
	{
		var maxTime:Float = 1;
		if (FlxG.sound.music != null)
			maxTime = Math.max(1, FlxG.sound.music.length);

		var opt:CharmOption = new CharmOption(Language.getPhrase('pause_skip_time', 'Skip Time'),
			'Pick a time, then hit Skip to jump there', INT, curTime);

		opt.getter = function() return curTime;
		opt.setter = function(v) { curTime = v; };

		opt.minValue = 0;
		opt.maxValue = maxTime;
		opt.changeValue = 1000;     // 步长 1000ms
		opt.decimals = 0;
		opt.valueFormatter = function(v:Float):String return formatSkipTime(v);

		return opt;
	}

	function formatSkipTime(ms:Float):String
	{
		var cur:String = FlxStringUtil.formatTime(Math.max(0, Math.floor(ms / 1000)), false);
		var total:String = '0:00';
		if (FlxG.sound.music != null)
			total = FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
		return cur + ' / ' + total;
	}

	function makeSkipActionOption():Option
	{
		var opt:Option = new CharmActionOption(
			Language.getPhrase('pause_skip_apply', 'Skip to Time'),
			'Jump to the selected time',
			Language.getPhrase('pause_skip_apply', 'Skip'));
		opt.action = function() {
			if (curTime < Conductor.songPosition)
			{
				PlayState.startOnTime = curTime;
				if (host != null) host.restartSong(true);
				return;
			}

			runHostAction(function() {
				if (curTime != Conductor.songPosition)
				{
					PlayState.instance.clearNotesBefore(curTime);
					PlayState.instance.setSongTime(curTime);
				}
				if (host != null) host.closeMenu();
			});
		};
		return opt;
	}

	function makePracticeOption():Option
	{
		var opt:CharmOption = new CharmOption(Language.getPhrase('pause_toggle_practice_mode', 'Toggle Practice'),
			'Practice mode: no death, retry sections freely', BOOL, PlayState.instance.practiceMode);

		opt.getter = function() return PlayState.instance.practiceMode;
		// BoolButton 已经把"取反后的新值"算好了（BoolButton.hx:152-153），所以这里是 set 不是 toggle
		opt.setter = function(v) { if (host != null) host.setPracticeMode(v == true); };

		return opt;
	}

	function makeBotplayOption():Option
	{
		var opt:CharmOption = new CharmOption(Language.getPhrase('pause_toggle_botplay', 'Toggle Botplay'),
			'Let the engine play the chart for you', BOOL, PlayState.instance.cpuControlled);

		opt.getter = function() return PlayState.instance.cpuControlled;
		opt.setter = function(v) { if (host != null) host.setBotplay(v == true); };

		return opt;
	}

	function runHostAction(act:Void->Void):Void
	{
		if (act != null) act();
		animateOutAndClose();
	}
}
