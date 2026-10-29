package nmv.objects;

import flixel.group.FlxGroup.FlxTypedGroup;

/**
 * 字幕容器（NMV FunkinCaptionGroup）。脚本只用到 defaultY 与成员增删，
 * NMV 的播放队列（playing/time/queue）不参与，留字段保持 API 形状。
 */
class FunkinCaptionGroup extends FlxTypedGroup<FunkinCaption>
{
	public var defaultY:Float;
	public var playing:Bool = false;
	public var time:Float = 0;
	public var cleanup:Bool = true;

	public function new(defaultY:Float = 650)
	{
		super();
		this.defaultY = defaultY;
	}
}
