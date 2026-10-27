package nmv.objects;

import flixel.FlxSprite;

/**
 * NMV 宠物（Pet 继承 Bopper）的行为桩：逻辑放行、宠物本体不显示。
 *
 * 早期版本是裸匿名对象 {curPet, loadPet}，monotone/piptowers 等脚本会碰
 * pet.origin.set / pet.alpha 这类 FlxSprite 面，改成 FlxSprite 实例补齐。
 */
class PetStub extends FlxSprite
{
	public var curPet:String = '';

	public var loadPet:(?name:String, ?force:Bool) -> Dynamic = function(?name:String = '', ?force:Bool = false):Dynamic return null;

	// NMV flixel fork 的 FlxBasic 面（zIndex/skew）与 FlxSprite 的
	// useRenderTexture：FE 没有，脚本直接赋值会炸，这里按 API 兼容补字段（无渲染语义）
	public var zIndex:Int = 0;
	public var skew:flixel.math.FlxPoint = flixel.math.FlxPoint.get();
	public var useRenderTexture:Bool = false;

	public function new()
	{
		super();
		visible = false;
	}
}
