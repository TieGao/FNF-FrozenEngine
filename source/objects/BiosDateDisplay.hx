package objects;

import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup;
import Date;

class BiosDateDisplay extends FlxSpriteGroup
{
	var dateText:FlxText;
	var timeText:FlxText;
	
	// 字体配置
	var fontSize:Int = 20;
	var textColor:FlxColor = FlxColor.WHITE;
	var shadowColor:FlxColor = FlxColor.BLACK;
	
	// 时间格式
	var showSeconds:Bool = true;
	var militaryTime:Bool = false;
	var showDate:Bool = true;
	
	// 更新时间间隔（毫秒）
	var updateInterval:Int = 1000;
	var lastUpdate:Float = 0;
	
	// 显示顺序：时间在前还是日期在前
	var timeFirst:Bool = true;
	
	public function new(x:Float = 0, y:Float = 0, fontSize:Int = 20, color:FlxColor = FlxColor.WHITE, timeFirst:Bool = true)
	{
		super(x, y + 20);
		this.fontSize = fontSize;
		this.textColor = color;
		this.timeFirst = timeFirst;
		createDisplay();
	}
	
	function createDisplay():Void
	{
		// 创建日期时间文本
		dateText = new FlxText(0, 0, 0, "", fontSize);
		dateText.setFormat(Paths.font("vcr.ttf"), fontSize, textColor, LEFT, OUTLINE, shadowColor);
		dateText.borderSize = 1;
		dateText.scrollFactor.set();
		
		timeText = new FlxText(0, 0, 0, "", fontSize);
		timeText.setFormat(Paths.font("vcr.ttf"), fontSize, textColor, LEFT, OUTLINE, shadowColor);
		timeText.borderSize = 1;
		timeText.scrollFactor.set();
		
		add(dateText);
		add(timeText);
		
		// 初始更新
		updateDateTime();
		
		// 根据显示顺序排列
		arrangeTexts();
	}
	
	function updateDateTime():Void
	{
		var now:Date = Date.now();
		
		// 格式化日期：月份/日期/年份
		var month:Int = now.getMonth() + 1; // getMonth() 返回 0-11
		var day:Int = now.getDate();
		var year:Int = now.getFullYear();
		
		// 格式化时间
		var hour:Int = now.getHours();
		var minute:Int = now.getMinutes();
		var second:Int = now.getSeconds();
		
		// 日期文本：月份/日期/年份
		var dateString:String = month + "/" + day + "/" + year;
		dateText.text = dateString;
		
		// 时间文本
		var timeString:String;
		
		if (militaryTime) {
			// 24小时制
			timeString = formatTwoDigits(hour) + ":" + formatTwoDigits(minute);
			if (showSeconds) {
				timeString += ":" + formatTwoDigits(second);
			}
		} else {
			// 12小时制
			var ampm:String = "AM";
			var displayHour:Int = hour;
			
			if (hour >= 12) {
				ampm = "PM";
				if (hour > 12) {
					displayHour = hour - 12;
				}
			}
			if (hour == 0) {
				displayHour = 12;
			}
			
			timeString = formatTwoDigits(displayHour) + ":" + formatTwoDigits(minute);
			if (showSeconds) {
				timeString += ":" + formatTwoDigits(second);
			}
			timeString += " " + ampm;
		}
		
		timeText.text = timeString;
		
		// 重新排列文本位置
		arrangeTexts();
	}
	
	function arrangeTexts():Void
	{
		if (timeFirst) {
			// 时间在前，日期在后
			timeText.x = 0;
			dateText.x = timeText.fieldWidth + 15;
		} else {
			// 日期在前，时间在后
			dateText.x = 0;
			timeText.x = dateText.fieldWidth + 15;
		}
		
		// Y坐标对齐
		timeText.y = 35;
		dateText.y = 35;
	}
	
	function formatTwoDigits(num:Int):String
	{
		return num < 10 ? "0" + num : Std.string(num);
	}
	
	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		
		// 定期更新时间
		lastUpdate += elapsed * 1000; // 转换为毫秒
		if (lastUpdate >= updateInterval) {
			updateDateTime();
			lastUpdate = 0;
		}
	}
	
	// 设置显示顺序
	public function setDisplayOrder(timeFirst:Bool):Void
	{
		this.timeFirst = timeFirst;
		updateDateTime();
	}
	
	// 设置显示选项的公共方法
	public function setShowSeconds(show:Bool):Void
	{
		showSeconds = show;
		updateDateTime();
	}
	
	public function setMilitaryTime(military:Bool):Void
	{
		militaryTime = military;
		updateDateTime();
	}
	
	public function setShowDate(show:Bool):Void
	{
		showDate = show;
		dateText.visible = show;
		if (!show) {
			timeText.x = 0; // 如果只显示时间，左对齐
		}
		updateDateTime();
	}
	
	public function setTextColor(color:FlxColor):Void
	{
		textColor = color;
		dateText.color = color;
		timeText.color = color;
	}
	
	public function setShadowColor(color:FlxColor):Void
	{
		shadowColor = color;
		dateText.setFormat(Paths.font("vcr.ttf"), fontSize, textColor, LEFT, OUTLINE, shadowColor);
		timeText.setFormat(Paths.font("vcr.ttf"), fontSize, textColor, LEFT, OUTLINE, shadowColor);
	}
	
	public function setFontSize(size:Int):Void
	{
		fontSize = size;
		dateText.setFormat(Paths.font("vcr.ttf"), fontSize, textColor, LEFT, OUTLINE, shadowColor);
		timeText.setFormat(Paths.font("vcr.ttf"), fontSize, textColor, LEFT, OUTLINE, shadowColor);
		updateDateTime(); // 重新计算位置
	}
	
	// 获取组件总宽度
	public function getTotalWidth():Float
	{
		return timeFirst ? 
			timeText.fieldWidth + 15 + dateText.fieldWidth : 
			dateText.fieldWidth + 15 + timeText.fieldWidth;
	}
	
	
	// 获取显示文本（用于调试）
	public function getDisplayText():String
	{
		if (timeFirst) {
			return timeText.text + "  " + dateText.text;
		} else {
			return dateText.text + "  " + timeText.text;
		}
	}
}