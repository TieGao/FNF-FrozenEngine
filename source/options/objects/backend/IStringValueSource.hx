package options.objects.backend;

/**
 * StringSelect 下拉条对数据源的最小接口。
 *
 * 之前 follow 写死 options.Option，KEOptionsMenu 的 KEOption 语义对不上
 * （KEOption.getValue() 返回整串 "name: < value >" 而不是裸值），复用不了。
 * 抽成接口后 options.Option 和 KEOption 都能直接当数据源，不引入包装层。
 *
 * 契约：
 * - `getValue()` 返回**裸值**（string → 当前字符串，color → FlxColor 的 Int），展示文本一律走 getOptionText
 * - `setValue()` 只改内存值 + 同步 curOption，落盘由紧随其后的 saveCurrentValue() 负责
 * - `change()` 触发即时生效副作用（对应 Option.onChange / KEOption.applyImmediateChanges）
 */
interface IStringValueSource
{
	public var options:Array<String>;
	public var curOption:Int;
	public var defaultValue:Dynamic;

	public function getValue():Dynamic;
	public function getOptionText(value:Dynamic):String;
	public function setValue(value:Dynamic):Void;
	public function change():Void;
	public function saveCurrentValue():Void;
}
