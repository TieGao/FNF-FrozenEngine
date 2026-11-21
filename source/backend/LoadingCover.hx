package backend;

import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import sys.FileSystem;

/**
 * loading 盖板：强调色底 + funkay 插画，合成成一张整屏图。
 *
 * funkay 原图是 RGB 无 alpha、自带黄绿背景，直接贴到强调色上会露出一块方色块，
 * 所以按背景色做软抠图把底色去掉、保留角色原色。底色和插画必须落在同一张图上：
 * 拆成两个半透明精灵时，插画轮廓区会叠两层 alpha，比四周纯色底更实。
 */
class LoadingCover
{
	// funkay.png 的背景色
	static inline var BG_R:Int = 0xCA;
	static inline var BG_G:Int = 0xFF;
	static inline var BG_B:Int = 0x4D;

	/** 与背景色的 RGB 距离小于它 = 纯背景 */
	static inline var KEY_IN:Float = 30;
	/** 大于它 = 纯主体，中间线性过渡，避免边缘留一圈黄绿描边 */
	static inline var KEY_OUT:Float = 80;

	public static function build(width:Int, height:Int):FlxGraphic
	{
		// 盖板是屏幕空间贴图，按 GPU 常见纹理上限钳一下
		var w:Int = Std.int(Math.max(1, Math.min(width, 4096)));
		var h:Int = Std.int(Math.max(1, Math.min(height, 4096)));

		var bmd:BitmapData = new BitmapData(w, h, true, UITheme.accent);

		var src:BitmapData = getFunkaySource();
		if (src != null && src.width > 0 && src.height > 0)
		{
			// contain 再放大 3%：保证角色头脚完整，又比按高度撑满略饱满
			var scale:Float = Math.min(w / src.width, h / src.height) * 1.03;
			var art:BitmapData = keyOutBackground(src, scale);

			if (art != null)
			{
				var m:Matrix = new Matrix();
				m.translate((w - art.width) * 0.5, (h - art.height) * 0.5);
				bmd.draw(art, m);
				art.dispose();
			}
		}

		return FlxGraphic.fromBitmapData(bmd);
	}

	/** funkay 的 CPU 位图；GPU caching 可能已经把缓存里的副本丢掉，兜底直接读文件 */
	static function getFunkaySource():BitmapData
	{
		var g:FlxGraphic = Paths.image('funkay', null, false);
		var bmd:BitmapData = (g != null) ? g.bitmap : null;
		if (bmd != null && bmd.width > 0 && bmd.image != null) return bmd;

		#if sys
		var fullKey:String = Language.getFileTranslation('images/funkay') + '.png';
		var resolved:ImageResolve = Paths.resolveImage(fullKey, null);
		if (resolved != null && resolved.file != null && FileSystem.exists(resolved.file))
			return BitmapData.fromFile(resolved.file);
		#end

		return null;
	}

	/** 抠掉黄绿背景、保留角色原色，返回带 alpha 的插画 */
	static function keyOutBackground(src:BitmapData, scale:Float):BitmapData
	{
		var sw:Int = Std.int(src.width * scale);
		var sh:Int = Std.int(src.height * scale);
		if (sw <= 0 || sh <= 0) return null;

		var out:BitmapData = new BitmapData(sw, sh, true, 0x00000000);
		var m:Matrix = new Matrix();
		m.scale(scale, scale);
		out.draw(src, m);

		var in2:Float = KEY_IN * KEY_IN;
		var out2:Float = KEY_OUT * KEY_OUT;

		for (y in 0...sh)
		{
			for (x in 0...sw)
			{
				var c:Int = out.getPixel32(x, y);
				var a:Int = (c >>> 24) & 0xFF;
				if (a == 0) continue;

				var dr:Int = ((c >> 16) & 0xFF) - BG_R;
				var dg:Int = ((c >> 8) & 0xFF) - BG_G;
				var db:Int = (c & 0xFF) - BG_B;
				var d2:Float = dr * dr + dg * dg + db * db;

				var keep:Float;
				if (d2 <= in2) keep = 0;
				else if (d2 >= out2) keep = 1;
				else keep = (Math.sqrt(d2) - KEY_IN) / (KEY_OUT - KEY_IN);

				var na:Int = Std.int(a * keep);
				// 只改 alpha，RGB 原样保留
				out.setPixel32(x, y, na <= 0 ? 0 : (na << 24) | (c & 0xFFFFFF));
			}
		}

		return out;
	}
}
