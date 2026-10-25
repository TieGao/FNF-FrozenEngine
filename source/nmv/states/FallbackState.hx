package nmv.states;

import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

/**
 * 脚本加载失败等场景的兜底 State：显示错误信息，按确认键执行回调。
 */
class FallbackState extends MusicBeatState
{
	final warningMessage:String;

	final continueCallback:Void->Void;

	public function new(warningMessage:String, continueCallback:Void->Void)
	{
		this.continueCallback = continueCallback;
		this.warningMessage = warningMessage;
		super();
	}

	override function create()
	{
		var error = new FlxText(0, 0, 0, 'ERROR', 46);
		error.setFormat(Paths.font("vcr.ttf"), 46, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
		error.screenCenter(X);
		error.y = 25;
		add(error);
		FlxTween.tween(error, {y: error.y + 45}, 2, {ease: FlxEase.sineInOut, type: PINGPONG});

		var text = new FlxText(25, 0, FlxG.width - 50, warningMessage, 32);
		text.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(text);
		text.screenCenter(Y);

		var text2 = new FlxText(0, FlxG.height - 25 - 32, FlxG.width, 'Press Confirm to continue.', 32);
		text2.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(text2);

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.ACCEPT)
		{
			persistentUpdate = false;
			continueCallback();
		}
	}
}
