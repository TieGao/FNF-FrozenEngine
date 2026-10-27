package nmv.objects;

import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.math.FlxPoint;

import flxanimate.PsychFlxAnimate;

import backend.Paths;

/**
 * NMV funkin.objects.FunkinSprite 的 FE 等价物。
 *
 * 用 flxanimate 做基座（NMV 原版同为 FlxAnimate 子类），只补样本实际用到的表面：
 * 链式构造、loadAtlas、playAnim。其余 API 由 FlxSprite/PsychFlxAnimate 原生提供。
 */
class FunkinSprite extends PsychFlxAnimate
{
	// NMV 的 flixel fork 在 FlxBasic 上有 zIndex / skew，语料舞台脚本直接用；
	// FE pin 的 flixel 6.2.0 没有，这里按 API 兼容补字段（无渲染语义：zIndex
	// 不参与排序、skew 不参与绘制，视觉差异按已知限制记录）。
	public var zIndex:Int = 0;
	public var skew:FlxPoint = FlxPoint.get();

	public function new(?x:Float = 0, ?y:Float = 0, ?graphic:FlxGraphicAsset = null)
	{
		super(x, y);

		if (graphic != null) loadGraphic(graphic);
	}

	/**
	 * 加载图集，两档布局：
	 * - Psych/FE 的 spritemap 约定（images/<path>/spritemap.json + png）
	 * - Adobe Animate 布局（images/<path>/Animation.json + spritemap1.json/png），
	 *   语料实测的 bfIntro / charlesClouds 是这一档，FE 的 loadAnimateAtlas 原生支持
	 * 其他布局（NMV 的 sparrow/packer 直读）遇到会显式抛出，避免静默无动画。
	 *
	 * 不叫 loadAtlas：flxanimate 库的同名方法是 Adobe Animate 布局且返回 Void，
	 * 覆盖会撞签名；脚本里的 loadAtlas 调用由 InterpEx.fcall 特判转到这里。
	 */
	public function loadNmvAtlas(path:String):FunkinSprite
	{
		if (Paths.getTextFromFile('images/$path/spritemap.json') == null
			&& Paths.getTextFromFile('images/$path/Animation.json') == null)
		{
			// NMV 的 loadAtlas 对缺图集是容忍的（frames 落空、精灵无动画、不中断脚本，
			// 语料 walkes 等图集在发行版里由引擎 assets 补齐）——保持同语义，只告警
			flixel.FlxG.log.warn('FunkinSprite.loadAtlas("$path"): no atlas found (looked for spritemap.json / Animation.json under images/$path).');
			return this;
		}

		Paths.loadAnimateAtlas(this, path);
		return this;
	}

	/** 播放动画；force 决定是否重启动画。图集未加载时跳过（flxanimate 对空控制器 play 会裸 NPE）。 */
	public function playAnim(name:String, force:Bool = false, reversed:Bool = false, ?frame:Int = 0):Void
	{
		if (anim == null || anim.getByName(name) == null) return;
		anim.play(name, force, reversed, frame);
	}
}
