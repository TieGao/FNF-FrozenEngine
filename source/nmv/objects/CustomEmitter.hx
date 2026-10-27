package nmv.objects;

import flixel.util.FlxPool.IFlxPooled;
import flixel.util.helpers.FlxRangeBounds;
import flixel.util.FlxDestroyUtil;
import flixel.effects.particles.FlxParticle;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.effects.particles.FlxEmitter;
import flixel.util.helpers.FlxPointRangeBounds;
import flixel.math.FlxPoint;

/**
 * NMV funkin.objects.CustomEmitter 原样移植（SnowEmitter 的基类）。
 */
class FlxPoint2 implements IFlxPooled
{
	public var active:Bool = true;
	public var x:FlxPoint = new FlxPoint();
	public var y:FlxPoint = new FlxPoint();

	public function new(minX:Float = 0, minY:Float = 0, ?maxX:Float, ?maxY:Float)
	{
		maxX ??= minX;
		maxY ??= minY;

		x.set(minX, maxX);
		y.set(minY, maxY);
	}

	public function put()
	{
		x = FlxDestroyUtil.put(x);
		y = FlxDestroyUtil.put(x);
	}

	// FE pin 的 flixel 6.2.0 池化接口比 NMV 的 5.x 多要求 putWeak
	public function putWeak()
	{
		put();
	}

	public function destroy() {}
}

// a slightly better emitter
class CustomEmitter extends FlxEmitter
{
	// NMV 的 flixel fork 在 FlxBasic 上有 zIndex/skew，语料（polus/maroon）直接用；
	// API 兼容壳，无渲染语义
	public var zIndex:Int = 0;
	public var skew:FlxPoint = FlxPoint.get();

	// this could be point bounds but like idc
	public var scrollFactor(default, null) = new FlxPoint2(1.0, 1.0);

	/**
	 * called on particle emittion
	 */
	public var onEmit(default, null) = new FlxTypedSignal<FlxParticle->Void>();

	public function new(x:Float = 0, y:Float = 0, size:Int = 0)
	{
		super(x, y, size);
	}

	override function emitParticle():FlxParticle
	{
		final _particle = super.emitParticle();

		_particle.scrollFactor.set();

		if (scrollFactor.active)
		{
			final scrollX = FlxG.random.float(scrollFactor.x.x, scrollFactor.x.y);
			final scrollY = FlxG.random.float(scrollFactor.y.x, scrollFactor.y.y);

			_particle.scrollFactor.set(scrollX, scrollY);
		}

		onEmit.dispatch(_particle);

		return _particle;
	}

	override function destroy()
	{
		if (onEmit != null) // this should never happen ???
		{
			onEmit.removeAll();
			onEmit.destroy();
			onEmit = null;
		}

		scrollFactor = FlxDestroyUtil.put(scrollFactor);

		super.destroy();
	}
}
