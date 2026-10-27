package nmv.objects;

/**
 * NMV 的 flxanimate fork（包名 animate.*）内部元素类的 API 兼容壳。
 * 语料 charles.hx 用 `new animate.internal.elements.FlxSpriteElement(cloud)`
 * 拿到子元素后置 active = false（隐藏 Animate 内部子件）；FE pin 的
 * flxanimate 4.0 没有这个内部 API —— 壳按原签名构造、字段可写，
 * 不真正联动显示树（对应子件保持可见），视觉差异按已知限制记录。
 */
class AnimateElementShim
{
	public var active:Bool = true;
	public var visible:Bool = true;

	public function new(?parent:Dynamic)
	{
		// NMV 原版持有父显示对象引用；FE 无对应内部结构，不持有
	}
}
