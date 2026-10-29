package nmv.shaders;

import flixel.FlxG;
import flixel.system.FlxAssets.FlxShader;

/**
 * NMV 脚本对 FlxShader 子类直接调 setFloat/setFloatArray/setBool（medbay/beach/
 * doubletrouble 的 rimlight 等）。标准 flixel 的 FlxShader 没有这些运行时方法，
 * NMV 的 flixel 栈才有——这里按 FlxRuntimeShader 的同名实现补成共享基类。
 */
class ShaderCompat extends FlxShader
{
	public function setFloat(name:String, value:Float):Void
	{
		final p:Dynamic = Reflect.field(data, name);
		if (p == null)
		{
			FlxG.log.warn('Shader float parameter "$name" not found.');
			return;
		}
		p.value = [value];
	}

	public function getFloat(name:String):Null<Float>
	{
		final p:Dynamic = Reflect.field(data, name);
		return (p == null) ? null : p.value[0];
	}

	public function setFloatArray(name:String, value:Array<Float>):Void
	{
		final p:Dynamic = Reflect.field(data, name);
		if (p == null)
		{
			FlxG.log.warn('Shader float[] parameter "$name" not found.');
			return;
		}
		p.value = value;
	}

	public function getFloatArray(name:String):Null<Array<Float>>
	{
		final p:Dynamic = Reflect.field(data, name);
		return (p == null) ? null : p.value;
	}

	public function setInt(name:String, value:Int):Void
	{
		final p:Dynamic = Reflect.field(data, name);
		if (p == null) return;
		p.value = [value];
	}

	public function setIntArray(name:String, value:Array<Int>):Void
	{
		final p:Dynamic = Reflect.field(data, name);
		if (p == null) return;
		p.value = value;
	}

	public function setBool(name:String, value:Bool):Void
	{
		final p:Dynamic = Reflect.field(data, name);
		if (p == null)
		{
			FlxG.log.warn('Shader bool parameter "$name" not found.');
			return;
		}
		p.value = [value];
	}

	public function getBool(name:String):Null<Bool>
	{
		final p:Dynamic = Reflect.field(data, name);
		return (p == null) ? null : p.value[0];
	}

	public function setBoolArray(name:String, value:Array<Bool>):Void
	{
		final p:Dynamic = Reflect.field(data, name);
		if (p == null) return;
		p.value = value;
	}

	public function setSampler2D(name:String, value:openfl.display.BitmapData):Void
	{
		final p:Dynamic = Reflect.field(data, name);
		if (p == null) return;
		p.input = value;
	}

	public function getSampler2D(name:String):Null<openfl.display.BitmapData>
	{
		final p:Dynamic = Reflect.field(data, name);
		return (p == null) ? null : p.input;
	}
}
