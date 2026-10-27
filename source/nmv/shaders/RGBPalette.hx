package nmv.shaders;

import flixel.FlxSprite;
import flixel.util.FlxColor;

/**
 * NMV funkin.game.shaders.RGBPalette / RGBShader 移植（non-batched 版本）。
 * 与 NMV 的差异：去掉 RGBGraphics（依赖 flixel 批渲染管线的 rgbR/rgbG 等
 * 内部字段，FE pin 的 flixel 6.2.0 没有这些）；语料只用 RGBPalette
 * （new / setColors / .shader）与 RGBShaderReference。
 * RGBShaderReference 不在 NMV 引擎里（finaleUI.hx 的 import 在 NMV 本体也
 * 解析失败），这里接 FE 的 shaders.RGBPalette.RGBShaderReference，签名相同。
 */
class RGBShader extends flixel.system.FlxAssets.FlxShader
{
	@:glVertexSource('
		#pragma header

		attribute vec3 r;
		attribute vec3 g;
		attribute vec3 b;
		attribute float mult;
		attribute float enabled;

		attribute float a_alpha;
		attribute float a_flash;

		varying vec3 _r;
		varying vec3 _g;
		varying vec3 _b;
		varying float _mult;
		varying float _enabled;

		varying float _a_alpha;
		varying float _a_flash;

		void main()
		{
			#pragma body
			_r = r;
			_g = g;
			_b = b;
			_mult = mult;
			_enabled = enabled;
			_a_alpha = a_alpha;
			_a_flash = a_flash;
		}
	')
	@:glFragmentSource('
		#pragma header

		varying vec3 _r;
		varying vec3 _g;
		varying vec3 _b;
		varying float _mult;
		varying float _enabled;

		varying float _a_alpha;
		varying float _a_flash;

		vec4 rgb(sampler2D bitmap, vec2 coord)
		{
			vec4 color = flixel_texture2D(bitmap, coord);

			if (!hasTransform || color.a == 0. || _mult == 0. || _enabled == 0) return color;

			vec4 newColor = color;
			newColor.rgb = min(color.r * _r + color.g * _g + color.b * _b, vec3(1.));
			newColor.a = color.a;

			color = mix(color, newColor, _mult * _enabled);

			if (color.a > 0.) return vec4(color.rgb, color.a);

			return vec4(0.);
		}

		void main()
		{
			vec4 texOutput = rgb(bitmap, openfl_TextureCoordv);

			if (_a_flash != 0.0) texOutput = mix(texOutput, vec4(1.), _a_flash) * texOutput.a;

			texOutput *= _a_alpha;

			gl_FragColor = texOutput;
		}
	')
	public function new()
	{
		super();
	}
}

class RGBPalette
{
	public var shader:RGBShader;

	public var r(default, set):FlxColor;
	public var g(default, set):FlxColor;
	public var b(default, set):FlxColor;
	public var mult(default, set):Float;
	public var alpha(default, set):Float;
	public var flash(default, set):Float;
	public var enabled(default, set):Bool;

	public function new(r:FlxColor = 0xFFFF0000, g:FlxColor = 0xFF00FF00, b:FlxColor = 0xFF0000FF, mult:Float = 1.0, alpha:Float = 1.0, flash:Float = 0.0)
	{
		shader = new RGBShader();

		this.r = r;
		this.g = g;
		this.b = b;
		this.mult = mult;
		this.alpha = alpha;
		this.flash = flash;
		this.enabled = true;
	}

	public function getColors():Array<FlxColor>
	{
		return [r, g, b];
	}

	public function setColors(colors:Array<FlxColor>):Void
	{
		r = colors[0];
		g = colors[1];
		b = colors[2];
	}

	function set_r(value:FlxColor):FlxColor
	{
		shader.data.r.value = [value.redFloat, value.greenFloat, value.blueFloat];
		return r = value;
	}

	function set_g(value:FlxColor):FlxColor
	{
		shader.data.g.value = [value.redFloat, value.greenFloat, value.blueFloat];
		return g = value;
	}

	function set_b(value:FlxColor):FlxColor
	{
		shader.data.b.value = [value.redFloat, value.greenFloat, value.blueFloat];
		return b = value;
	}

	function set_mult(value:Float):Float
	{
		shader.data.mult.value = [mult = value];
		return value;
	}

	function set_alpha(value:Float):Float
	{
		shader.data.a_alpha.value = [alpha = value];
		return value;
	}

	function set_flash(value:Float):Float
	{
		shader.data.a_flash.value = [flash = value];
		return value;
	}

	function set_enabled(value:Bool):Bool
	{
		shader.data.enabled.value = [value ? 1 : 0];
		return enabled = value;
	}
}
