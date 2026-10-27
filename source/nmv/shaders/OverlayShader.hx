package nmv.shaders;

import openfl.display.BitmapData;

import flixel.system.FlxAssets.FlxShader;

/**
 * NMV funkin.game.shaders.OverlayShader 原样移植（overlay 混合模式）。
 */
class OverlayShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		uniform sampler2D bitmapOverlay;

		vec4 overlay(vec4 base, vec4 blend)
		{
			if (blend.a == 0.) return base;

			vec3 baseN = (base.a > 0. ? base.rgb / base.a : vec3(0.));
			vec3 blendN = (blend.a > 0. ? blend.rgb / blend.a : vec3(0.));

			return vec4(mix(baseN, mix(1. - 2. * (1. - baseN) * (1. - blendN), 2. * baseN * blendN, step(baseN, vec3(.5))), blend.a) * base.a, base.a);
		}

		void main()
		{
			gl_FragColor = overlay(flixel_texture2D(bitmap, openfl_TextureCoordv), texture2D(bitmapOverlay, openfl_TextureCoordv));
		}
	')

	public function new()
	{
		super();
	}

	/**
	 * Assigns the bitmap to be used as the overlay.
	 * @param bitmap A BitmapData object containing the image to use as the overlay.
	 */
	public function setBitmapOverlay(bitmap:BitmapData):Void
	{
		this.bitmapOverlay.input = bitmap;
	}
}
