package substates;

import backend.RollLine;
import objects.CreditsRoll;

/**
 * 全屏「完整名单」滚动页。黑底 + 上下黑条裁切 + 底部操作提示。
 * 输入：按住 Enter/Space 加速、按住 P/Shift 暂停、BACK 返回 Credits；滚完自动返回。
 */
class CreditsRollSubState extends MusicBeatSubstate
{
	static inline var TOP_BAR_H:Float = 92;
	static inline var BOTTOM_BAR_H:Float = 68;

	var lines:Array<RollLine>;
	var roll:CreditsRoll;
	var hint:FlxText;
	var closing:Bool = false;

	public function new(lines:Array<RollLine>)
	{
		super();
		this.lines = lines;
	}

	override function create():Void
	{
		super.create();

		bgColor = FlxColor.BLACK;
		FlxG.mouse.visible = true;

		if (lines == null || lines.length == 0)
		{
			closeRoll();
			return;
		}

		roll = new CreditsRoll(lines);
		roll.setViewport(TOP_BAR_H, FlxG.height - BOTTOM_BAR_H);
		roll.restart();
		add(roll);

		// 上下黑条盖住滚出视口的字（比 camera.clipRect 稳，多相机不会漏）
		var topBar:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, Std.int(TOP_BAR_H), FlxColor.BLACK);
		topBar.scrollFactor.set();
		add(topBar);

		var bottomBar:FlxSprite = new FlxSprite(0, FlxG.height - BOTTOM_BAR_H)
			.makeGraphic(FlxG.width, Std.int(BOTTOM_BAR_H), FlxColor.BLACK);
		bottomBar.scrollFactor.set();
		add(bottomBar);

		var title:FlxText = new FlxText(44, 24, 0, 'CREDITS', 40);
		title.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.WHITE, LEFT);
		title.borderStyle = OUTLINE;
		title.borderColor = FlxColor.BLACK;
		title.borderSize = 3;
		title.antialiasing = ClientPrefs.data.antialiasing;
		title.scrollFactor.set();
		add(title);

		hint = new FlxText(44, FlxG.height - 46, FlxG.width - 88, '', 20);
		hint.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, RIGHT);
		hint.antialiasing = ClientPrefs.data.antialiasing;
		hint.scrollFactor.set();
		hint.alpha = 0.65;
		hint.text = 'HOLD ENTER/SPACE: FAST    -    HOLD P/SHIFT: PAUSE    -    BACK: BACK TO LIST';
		add(hint);
	}

	override function update(elapsed:Float):Void
	{
		if (!closing)
		{
			if (controls.BACK || FlxG.mouse.justPressedRight) closeRoll();
			else if (roll != null && roll.finished) closeRoll();
		}

		super.update(elapsed);
	}

	function closeRoll():Void
	{
		if (closing) return;
		closing = true;
		close();
	}

	override function destroy():Void
	{
		roll = null;
		super.destroy();
	}
}
