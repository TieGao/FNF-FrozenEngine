package nmv.shaders;

import openfl.display.BitmapData;

import flixel.FlxBasic;
import flixel.system.FlxAssets.FlxShader;

import backend.Paths;

/**
 * NMV funkin.game.shaders.HeatwaveShader 移植。
 * 与 NMV 的唯一差异：扭曲纹理在 NMV 是引擎 assets/legacy 的图，FE 没有这条资产，
 * 找不到时兜底生成一张中性灰位图（近似无扭曲），不让脚本加载中断。
 */
class HeatwaveShader extends FlxBasic
{
	public var shader(default, null):FabsShaderGLSL = new FabsShaderGLSL();

	var iTime:Float = 0;

	public function new():Void
	{
		super();
		final graphic = Paths.image('stages/polus/maroon/boiling/heatwave');
		shader.distortTexture.input = (graphic != null && graphic.bitmap != null) ? graphic.bitmap : makeFallbackTexture();
	}

	static function makeFallbackTexture():BitmapData
	{
		final bmp = new BitmapData(64, 64, false, 0xFF8080FF);
		bmp.colorTransform(bmp.rect, new openfl.geom.ColorTransform(1, 1, 1, 1, 0, 0, 128, 0));
		return bmp;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		iTime += elapsed;
		shader.iTime.value = [iTime];
	}
}

class FabsShaderGLSL extends FlxShader
{
	@:glFragmentSource('
        #pragma header

        uniform float iTime;

        uniform sampler2D distortTexture;

        void main(){
                vec2 p_m = openfl_TextureCoordv;
                vec2 p_d = p_m;

                p_d.t -= iTime * 0.05;
                p_d.t = mod(p_d.t, 1.0);

                vec4 dst_map_val = flixel_texture2D(distortTexture, p_d);

                vec2 dst_offset = dst_map_val.xy;
                dst_offset -= vec2(.5,.5);
                dst_offset *= 2.;
                dst_offset *= 0.009; //THIS CONTROLS THE INTENSITY [higher numbers = MORE WAVY]

                //reduce effect towards Y top
                dst_offset *= pow(p_m.t, 1.4); //THIS CONTROLS HOW HIGH UP THE SCREEN THE EFFECT GOES [higher numbers = less screen space]

                vec2 dist_tex_coord = p_m.st + dst_offset;
                gl_FragColor = flixel_texture2D(bitmap, dist_tex_coord);
        }')
	public function new()
	{
		super();
	}
}
