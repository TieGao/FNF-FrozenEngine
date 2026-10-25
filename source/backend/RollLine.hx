package backend;

/**
 * 滚动名单的一行。纯数据，不依赖 flixel —— 通用组件 `objects.CreditsRoll`
 * 与数据层 `backend.CreditsData` 都只依赖这个结构，互不依赖。
 */
typedef RollLine = {
	/** 左栏文字（组标题 / 子标题 / 人名） */
	var text:String;
	/** 右栏文字（职责）。空 = 单栏 */
	var second:String;
	/** 0 = 组标题  1 = 子分组  2 = 人物行  3 = 纯间隔（不建对象，只推进 y） */
	var style:Int;
	/** 本行之后额外留白 */
	var gapAfter:Float;
	/** '' = 白色 */
	var color:String;
	/** '' = 用 CreditsRoll 默认字体 */
	var font:String;
}
