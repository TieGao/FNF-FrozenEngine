package options;

import backend.Language;

class KEOptionCata extends FlxSprite
{
	public var title:String;
	public var options:Array<KEOption>;
	public var optionObjects:FlxTypedGroup<FlxText>;
	public var titleObject:FlxText;
	public var middle:Bool = false;

	public function new(x:Float, y:Float, _title:String, _options:Array<KEOption>, middleType:Bool = false)
	{
		super(x, y);
		title = _title;
		middle = middleType;
		
		// 不再在这里设置固定宽度，由上层控制
		// 宽度将在 create() 中被重新设置
		if (!middleType) {
			// 先创建一个默认尺寸，将在上层被覆盖
			makeGraphic(100, 40, FlxColor.BLACK);
		}
		alpha = 0.4;

		options = _options;
		optionObjects = new FlxTypedGroup<FlxText>();
		var localizedTitle = Language.getPhrase(title, title);
		
		// 使用屏幕宽度计算居中位置
		var screenWidth:Int = 1280;
		
		titleObject = new FlxText((middleType ? screenWidth / 2 : x), y + (middleType ? 0 : 8), 0, localizedTitle);
		titleObject.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK); // 字体稍微减小
		titleObject.borderSize = 2; // 边框减小

		if (middleType)
		{
			titleObject.x = 50 + ((screenWidth / 2) - (titleObject.fieldWidth / 2));
		}
		else
		{
			// 标题在选项卡内居中
			// x坐标将在上层被重新计算
		}

		titleObject.scrollFactor.set();
		scrollFactor.set();

		for (i in 0...options.length)
		{
			var opt = options[i];
			// 使用屏幕宽度计算选项位置
			var text = new FlxText((middleType ? screenWidth / 2 : 72), 120 + 54 + (46 * i), 0, opt.getValue());
			if (middleType)
			{
				text.screenCenter(X);
			}
			text.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK); // 字体大小
			text.borderSize = 2;
			text.borderQuality = 1;
			text.scrollFactor.set();
			optionObjects.add(text);
		}
	}

	public function changeColor(color:FlxColor)
	{
		// 保持当前尺寸，只改变颜色
		if (graphic != null) {
			makeGraphic(Std.int(width), Std.int(height), color);
		}
	}
}