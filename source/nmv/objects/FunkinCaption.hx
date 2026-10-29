package nmv.objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;

/**
 * NMV 1.1.2 的字幕（一条 = 半透明底板 + 文本）。
 *
 * 只搬脚本用到的面：set / text / visible。NMV 原版的时间轴排期（timestamp、
 * 逐字打字机）没搬，字幕一次性整条显示。
 */
class FunkinCaption extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var text:FlxText;

	public function new(?defaultY:Float = 500)
	{
		super();

		bg = new FlxSprite(0, 0).makeGraphic(1, 1, 0xAA000000);
		text = new FlxText(10, 0);
		add(bg);
		add(text);

		visible = false;
		set('', defaultY);
	}

	public function set(string:String = '', y:Float = 500, ?timestamp:Dynamic):FunkinCaption
	{
		this.y = y;
		text.text = nmv.data.Lang.str(string, string);
		text.setFormat(backend.Paths.font('vcr.ttf'), 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK);
		return recalculate();
	}

	public inline function recalculate():FunkinCaption
	{
		bg.setGraphicSize(Std.int(text.width + 20), Std.int(text.height));
		bg.updateHitbox();

		bg.x = this.x = Math.round((FlxG.width - bg.width) * .5);
		text.x = (this.x + 10);

		return this;
	}

	public var string(get, set):String;

	function get_string():String return text.text;

	function set_string(v:String):String return text.text = v;
}
