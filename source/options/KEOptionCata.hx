package options;

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
		if (!middleType)
			makeGraphic(295, 64, FlxColor.BLACK);
		alpha = 0.4;

		options = _options;
		optionObjects = new FlxTypedGroup<FlxText>();
		titleObject = new FlxText((middleType ? 1180 / 2 : x), y + (middleType ? 0 : 16), 0, title);
		titleObject.setFormat(Paths.font("vcr.ttf"), 35, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		titleObject.borderSize = 3;

		if (middleType)
		{
			titleObject.x = 50 + ((1180 / 2) - (titleObject.fieldWidth / 2));
		}
		else
			titleObject.x += (width / 2) - (titleObject.fieldWidth / 2);

		titleObject.scrollFactor.set();
		scrollFactor.set();

		for (i in 0...options.length)
		{
			var opt = options[i];
			var text = new FlxText((middleType ? 1180 / 2 : 72), 120 + 54 + (46 * i), 0, opt.getValue());
			if (middleType)
			{
				text.screenCenter(X);
			}
			text.setFormat(Paths.font("vcr.ttf"), 35, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			text.borderSize = 3;
			text.borderQuality = 1;
			text.scrollFactor.set();
			optionObjects.add(text);
		}
	}

	public function changeColor(color:FlxColor)
	{
		makeGraphic(295, 64, color);
	}
}