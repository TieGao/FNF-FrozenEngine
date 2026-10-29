package nmv.backend.math;

import flixel.util.FlxPool;

/**
 * 三维向量（NMV `funkin.backend.math.Vector3` 的移植，源自 lime.math.Vector4 改法）。
 * 语料里 shader / skew 相关脚本按这个类名 import，实际只用到构造与分量读写。
 */
class Vector3 implements IFlxPooled
{
	static final _pool = new FlxPool<Vector3>(() -> new Vector3());

	public static function get(x:Float = 0, y:Float = 0, z:Float = 0):Vector3
	{
		return _pool.get().setTo(x, y, z);
	}

	public static inline function recycle(x:Float = 0, y:Float = 0, z:Float = 0):Vector3
	{
		return _pool.get().setTo(x, y, z);
	}

	public inline function put():Void
	{
		setTo(0, 0, 0);
		_pool.put(this);
	}

	public inline function putWeak():Void {}

	public function destroy():Void {}

	public static var X_AXIS(get, never):Vector3;
	public static var Y_AXIS(get, never):Vector3;
	public static var Z_AXIS(get, never):Vector3;

	public var length(get, never):Float;
	public var lengthSquared(get, never):Float;

	public var x:Float;
	public var y:Float;
	public var z:Float;

	public function new(x:Float = 0.0, y:Float = 0.0, z:Float = 0.0)
	{
		setTo(x, y, z);
	}

	public inline function add(a:Vector3, ?result:Vector3):Vector3
	{
		if (result == null) result = Vector3.get();
		result.setTo(this.x + a.x, this.y + a.y, this.z + a.z);
		return result;
	}

	public static inline function angleBetween(a:Vector3, b:Vector3):Float
	{
		var a0 = a.clone();
		a0.normalize();
		var b0 = b.clone();
		b0.normalize();
		return Math.acos(a0.dotProduct(b0));
	}

	public inline function clone():Vector3
	{
		return Vector3.get(x, y, z);
	}

	public function lerp(goal:Vector3, alpha:Float):Vector3
	{
		return Vector3.get(alpha * goal.x + x * (1 - alpha), alpha * goal.y + y * (1 - alpha), alpha * goal.z + z * (1 - alpha));
	}

	public inline function copyFrom(sourceVector3:Vector3):Void
	{
		x = sourceVector3.x;
		y = sourceVector3.y;
		z = sourceVector3.z;
	}

	public inline function crossProduct(a:Vector3, ?result:Vector3):Vector3
	{
		if (result == null) result = Vector3.get();
		result.setTo(y * a.z - z * a.y, z * a.x - x * a.z, x * a.y - y * a.x);
		return result;
	}

	public inline function decrementBy(a:Vector3):Void
	{
		x -= a.x;
		y -= a.y;
		z -= a.z;
	}

	public inline static function distance(pt1:Vector3, pt2:Vector3):Float
	{
		var dx = pt2.x - pt1.x;
		var dy = pt2.y - pt1.y;
		var dz = pt2.z - pt1.z;
		return Math.sqrt(dx * dx + dy * dy + dz * dz);
	}

	public inline static function distanceSquared(pt1:Vector3, pt2:Vector3):Float
	{
		var dx = pt2.x - pt1.x;
		var dy = pt2.y - pt1.y;
		var dz = pt2.z - pt1.z;
		return dx * dx + dy * dy + dz * dz;
	}

	public inline function dotProduct(a:Vector3):Float
	{
		return x * a.x + y * a.y + z * a.z;
	}

	public inline function equals(toCompare:Vector3):Bool
	{
		return x == toCompare.x && y == toCompare.y && z == toCompare.z;
	}

	public inline function incrementBy(a:Vector3):Void
	{
		x += a.x;
		y += a.y;
		z += a.z;
	}

	public inline function nearEquals(toCompare:Vector3, tolerance:Float):Bool
	{
		return Math.abs(x - toCompare.x) < tolerance && Math.abs(y - toCompare.y) < tolerance && Math.abs(z - toCompare.z) < tolerance;
	}

	public inline function negate():Void
	{
		x *= -1;
		y *= -1;
		z *= -1;
	}

	public inline function normalize():Float
	{
		var l = length;
		if (l != 0)
		{
			x /= l;
			y /= l;
			z /= l;
		}
		return l;
	}

	public inline function scaleBy(s:Float):Void
	{
		x *= s;
		y *= s;
		z *= s;
	}

	public inline function setTo(xa:Float, ya:Float, za:Float):Vector3
	{
		x = xa;
		y = ya;
		z = za;
		return this;
	}

	public inline function subtract(a:Vector3, ?result:Vector3):Vector3
	{
		if (result == null) result = Vector3.get();
		result.setTo(x - a.x, y - a.y, z - a.z);
		return result;
	}

	public inline function toString():String
	{
		return 'Vector3($x, $y, $z)';
	}

	inline function get_length():Float
		return Math.sqrt(x * x + y * y + z * z);

	inline function get_lengthSquared():Float
		return x * x + y * y + z * z;

	inline static function get_X_AXIS():Vector3
		return Vector3.get(1, 0, 0);

	inline static function get_Y_AXIS():Vector3
		return Vector3.get(0, 1, 0);

	inline static function get_Z_AXIS():Vector3
		return Vector3.get(0, 0, 1);
}
