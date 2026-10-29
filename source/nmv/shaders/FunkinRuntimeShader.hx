package nmv.shaders;

import flixel.FlxG;
import flixel.addons.display.FlxRuntimeShader;
import flixel.addons.system.macros.FlxRuntimeShaderMacro;

/**
 * NMV funkin.backend.FunkinShader.FunkinRuntimeShader 原样移植：
 * 运行时 shader 的防崩壳——GLSL 编译失败时退回纯色采样模板，不中断整局。
 * （NMV 原版落 Logger + crash_dump；这里落 bread.log。）
 */
class FunkinRuntimeShader extends FlxRuntimeShader
{
	override function __createGLProgram(vertexSource:String, fragmentSource:String):lime.graphics.opengl.GLProgram
	{
		try
		{
			return super.__createGLProgram(vertexSource, fragmentSource);
		}
		catch (e:Dynamic)
		{
			backend.Bread.crumb('FunkinRuntimeShader compile failed: $e');
			FlxG.log.error('FunkinRuntimeShader compile failed, fallback to template: $e');

			@:privateAccess
			return super.__createGLProgram(vertexSource, TEMPLATE_FRAG);
		}
	}

	/** 编译失败时的兜底片元：正常采样输出。 */
	static final TEMPLATE_FRAG:String = FlxRuntimeShaderMacro.retrieveMetadata('glFragmentHeader')
		+ "
		void main()
		{
			gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv);
		}
	";
}
