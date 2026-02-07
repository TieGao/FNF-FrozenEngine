package backend;

import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.text.AntiAliasType;

class PsychText extends FlxText
{
	public function new(x:Float = 0, y:Float = 0, width:Float = 0, text:String = "", size:Int = 8)
	{
		super(x, y, width, text, size);
		applyPsychSettings();
	}
	
	private function applyPsychSettings():Void
	{
		// 延迟设置，确保textField已创建
		haxe.Timer.delay(function() {
			if (this.textField != null)
			{
				// 关键设置：让像素字体锐利
				this.textField.antiAliasType = AntiAliasType.ADVANCED;
				this.textField.sharpness = 400;
				
				#if !flash
				// 非Flash平台可以设置网格对齐
				this.textField.gridFitType = openfl.text.GridFitType.PIXEL;
				#end
			}
		}, 10);
		
		// 设置Psych Engine默认的边框样式
		this.antialiasing = false;
		
		// 如果当前没有边框，添加默认边框
		if (this.borderStyle == NONE)
		{
			this.borderStyle = OUTLINE;
			this.borderSize = 2;
			this.borderColor = FlxColor.BLACK;
		}
		
		// 确保使用最高质量的边框
		this.borderQuality = 1.0;
		
		// 标记需要重绘
		this._regen = true;
	}
	
	override public function setFormat(?font:String, size:Int = 8, color:FlxColor = FlxColor.WHITE, 
		?alignment:FlxTextAlign, ?borderStyle:FlxTextBorderStyle, borderColor:FlxColor = FlxColor.TRANSPARENT, 
		embeddedFont:Bool = true):FlxText
	{
		var result = super.setFormat(font, size, color, alignment, borderStyle, borderColor, embeddedFont);
		
		// 确保设置被应用
		applyPsychSettings();
		
		return result;
	}
	
	override function set_antialiasing(value:Bool):Bool
	{
		var result = super.set_antialiasing(value);
		
		// 确保OpenFL参数正确
		if (this.textField != null)
		{
			if (value)
			{
				this.textField.antiAliasType = AntiAliasType.NORMAL;
				this.textField.sharpness = 100;
			}
			else
			{
				this.textField.antiAliasType = AntiAliasType.ADVANCED;
				this.textField.sharpness = 400;
			}
		}
		
		return result;
	}
	
	override function set_text(value:String):String
	{
		var result = super.set_text(value);
		// 文本改变后确保设置正确
		haxe.Timer.delay(applyPsychSettings, 1);
		return result;
	}
	
	override function set_font(value:String):String
	{
		var result = super.set_font(value);
		
		// 如果是vcr字体，确保设置正确
		if (value != null && value.toLowerCase().indexOf("vcr") != -1)
		{
			this.antialiasing = false;
			applyPsychSettings();
		}
		
		return result;
	}
}