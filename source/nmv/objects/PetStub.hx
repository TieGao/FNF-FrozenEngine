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

	/** NMV 宠物旗标（rgb / 皮肤变体等），脚本用 pet.getFlag('rgb') 判分支 */
	public var flags:Map<String, Dynamic> = [];

	/** NMV 1.1.1 起的宠物变更信号（脚本 pet.onChange.add(fn)） */
	public var onChange:flixel.util.FlxSignal.FlxTypedSignal<Dynamic->Void> = new flixel.util.FlxSignal.FlxTypedSignal();

	public function getFlag(flag:String):Dynamic
	{
		return flags.get(flag);
	}

	// monotone.hx 的 `new funkin.objects.Pet().loadPet(custom).destroy()` 链式刷新：
	// 返回 this 让临时实例链走通（构造的PetStub就是一次性对象，destroy 无副作用）。
	// 闭包在构造函数里赋值——字段初始化表达式里不能引用 this。
	public var loadPet:(?name:String, ?force:Bool) -> Dynamic;

	// NMV flixel fork 的 FlxBasic 面（zIndex/skew）与 FlxSprite 的
	// useRenderTexture：FE 没有，脚本直接赋值会炸，这里按 API 兼容补字段（无渲染语义）
	public var zIndex:Int = 0;
	public var skew:flixel.math.FlxPoint = flixel.math.FlxPoint.get();
	public var useRenderTexture:Bool = false;

	// 角色脚本把 parent 当 Bopper 写 parent.animCurFrame（bf-running），补 NMV 同名读写口
	public var animCurFrame(get, set):Int;

	inline function get_animCurFrame():Int
	{
		return (animation == null || animation.curAnim == null) ? 0 : animation.curAnim.curFrame;
	}

	inline function set_animCurFrame(value:Int):Int
	{
		if (animation != null && animation.curAnim != null) animation.curAnim.curFrame = value;
		return value;
	}

	// 角色脚本 parent 面（bf-running 读 parent.getAnimName().contains(...)）；
	// 缺了会经 fcall 的 null 级联报成误导性的 "Invalid access to field contains"
	public function getAnimName():String
	{
		return (animation != null && animation.curAnim != null) ? animation.curAnim.name : '';
	}

	public function new()
	{
		super();
		visible = false;
		loadPet = function(?name:String = '', ?force:Bool = false):Dynamic return this;
	}
}
