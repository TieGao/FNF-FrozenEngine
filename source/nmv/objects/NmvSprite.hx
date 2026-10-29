package nmv.objects;

import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.util.FlxColor;

/**
 * 注册给脚本的 'FlxSprite'：NMV 的 flixel fork 在 FlxBasic 上有 zIndex / skew，
 * 语料舞台脚本直接用（toogus/victory 的 zIndex、lounge 的 skew），FE pin 的
 * flixel 6.2.0 没有 —— 这个子类按 API 兼容补字段。
 *
 * 注意：两个字段都**无渲染语义**（zIndex 不参与排序、skew 不参与绘制），
 * 与 NMV 的视觉差异按已知限制记录；脚本自己 new 出来的精灵才有这些字段。
 */
class NmvSprite extends FlxSprite
{
	public var zIndex:Int = 0;
	public var skew:FlxPoint = FlxPoint.get();

	/**
	 * NMV 1.1.x 的便捷建图（黑幕等）：按给定尺寸画纯色图并返回自身。
	 * 脚本写成 `new FlxSprite().makeScaledGraphic(w, h, color)`，缺了会在调用处报 Null Function Pointer。
	 */
	public function makeScaledGraphic(width:Float, height:Float, color:FlxColor = FlxColor.WHITE):NmvSprite
	{
		makeGraphic(Std.int(width), Std.int(height), color);
		return this;
	}

	public function new(?X:Float = 0, ?Y:Float = 0, ?SimpleGraphic:FlxGraphicAsset)
	{
		super(X, Y, SimpleGraphic);
	}

	/**
	 * NMV FlxSprite.loadFromSheet(path, frameName)：从 sparrow 图集里取指定帧
	 * 名（前缀匹配）建单帧动画并定位到该帧。语料 defeat/finalem 的舞台用。
	 * 缺图集时告警继续（与 loadAtlas 同语义），返回自身支持链式调用。
	 */
	public function loadFromSheet(path:String, frameName:String):NmvSprite
	{
		final frames = backend.Paths.getSparrowAtlas(path);
		if (frames == null || frames.frames.length == 0)
		{
			flixel.FlxG.log.warn('FlxSprite.loadFromSheet("$path", "$frameName"): atlas not found.');
			return this;
		}

		this.frames = frames;
		animation.addByPrefix('nmv_sheet', frameName, 0, false);
		if (animation.getByName('nmv_sheet') != null) animation.play('nmv_sheet', true, false, 0);
		else flixel.FlxG.log.warn('FlxSprite.loadFromSheet("$path", "$frameName"): no frames matching "$frameName".');
		return this;
	}
}
