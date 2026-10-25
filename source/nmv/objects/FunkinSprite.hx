package nmv.objects;

import flixel.system.FlxAssets.FlxGraphicAsset;

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
	public function new(?x:Float = 0, ?y:Float = 0, ?graphic:FlxGraphicAsset = null)
	{
		super(x, y);

		if (graphic != null) loadGraphic(graphic);
	}

	/**
	 * 按 Psych/FE 的 spritemap 约定加载图集（images/<path>/spritemap.json + png）。
	 * NMV 的 sparrow/packer/texture-atlas 布局与 Adobe Animate 布局未搬，
	 * 遇到会显式抛出，避免静默无动画。
	 *
	 * 不叫 loadAtlas：flxanimate 库的同名方法是 Adobe Animate 布局且返回 Void，
	 * 覆盖会撞签名；脚本里的 loadAtlas 调用由 InterpEx.fcall 特判转到这里。
	 */
	public function loadNmvAtlas(path:String):FunkinSprite
	{
		if (Paths.getTextFromFile('images/$path/spritemap.json') == null)
		{
			throw 'FunkinSprite.loadAtlas("$path"): only Psych spritemap layout (images/$path/spritemap.json) is supported in this port.';
		}

		Paths.loadAnimateAtlas(this, path);
		return this;
	}

	/** 播放动画；force 决定是否重启动画。 */
	public function playAnim(name:String, force:Bool = false, reversed:Bool = false, ?frame:Int = 0):Void
	{
		anim.play(name, force, reversed, frame);
	}
}
