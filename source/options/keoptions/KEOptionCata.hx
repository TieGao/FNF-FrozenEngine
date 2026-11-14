package options.keoptions;

import backend.Language;

/**
 * KEOptionsMenu 顶部选项卡：分类底板 + 标题文字 + 选中下划线。
 * 行列表不再挂在分类上 —— 行由 KEOptionsMenu 按「根列表 / 子视图」统一构建（KEOptionRow）。
 */
class KEOptionCata extends FlxSprite
{
	public var title:String;
	public var options:Array<KEOption>;
	public var titleObject:FlxText;

	/** 选中时展开的横向线条；宿主菜单负责创建与动效 */
	public var underline:FlxSprite;

	public function new(x:Float, y:Float, _title:String, _options:Array<KEOption>)
	{
		super(x, y);
		title = _title;
		options = _options;

		// 先创建一个默认尺寸，将在上层被覆盖
		makeGraphic(100, 40, FlxColor.BLACK);
		alpha = 0.4;

		var localizedTitle = Language.getPhrase(title, title);
		titleObject = new FlxText(x, y + 8, 0, localizedTitle);
		titleObject.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleObject.borderSize = 2;
		titleObject.scrollFactor.set();
		scrollFactor.set();
	}

	public function changeColor(color:FlxColor)
	{
		// 保持当前尺寸，只改变颜色
		if (graphic != null) {
			makeGraphic(Std.int(width), Std.int(height), color);
		}
	}
}
