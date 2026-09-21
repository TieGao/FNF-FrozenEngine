package options.objects.win8;

import shapeEx.Rect;

/**
 * 设置面板里的分组小标题。
 *
 * 面板上所有分组被拼成一页长列表时，用它来分隔不同分组的选项块：
 * 一行 13px 的浅色标题 + 一条 1px 分割线，视觉上跟 Win10 设置页的分组标题一致。
 *
 * 坐标注意：FlxSpriteGroup 的子元素坐标是绝对的（add() 时会加上 group.x/y），
 * 所以这里在 add() 之前就把子元素放在"组内坐标"上，不要 add 之后再改。
 */
class Win8CharmSection extends FlxSpriteGroup
{
	/** 分组标题行高 */
	public static inline var SECTION_H:Float = 42;
	/** 左右内边距，跟 Win8CharmRow.PAD_X 对齐 */
	static inline var PAD_X:Float = 14;

	/** 这个分组对应 charms 数组里的下标 */
	public var charmIndex:Int = 0;
	public var charmId:String = '';

	public var label:FlxText;
	public var line:Rect;

	public var baseY:Float = 0;
	public var rowH:Float = SECTION_H;

	public function new(x:Float, y:Float, w:Float, charmIndex:Int, id:String, text:String)
	{
		super(x, y);
		UITheme.ensure();

		this.charmIndex = charmIndex;
		this.charmId = id;

		label = new FlxText(PAD_X, 12, w - PAD_X * 2, text != null ? text : '', 13);
		label.setFormat(Paths.font('montserrat.ttf'), 13, UITheme.textSecondary, LEFT);
		label.borderStyle = NONE;
		label.antialiasing = ClientPrefs.data.antialiasing;
		add(label);

		line = new Rect(PAD_X, SECTION_H - 1, w - PAD_X * 2, 1, 0, 0, UITheme.divider, 0.6);
		line.antialiasing = ClientPrefs.data.antialiasing;
		add(line);
	}

	public function setRowMeta(baseY:Float, rowH:Float):Void
	{
		this.baseY = baseY;
		this.rowH = rowH;
	}

	public function setLabel(text:String):Void
	{
		if (label != null) label.text = (text != null) ? text : '';
	}

	public function refreshTheme():Void
	{
		if (label != null) label.color = UITheme.textSecondary;
		if (line != null) line.color = UITheme.divider;
	}
}
