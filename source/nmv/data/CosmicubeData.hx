package nmv.data;

/**
 * NMV `funkin.data.CosmicubeData` 的桩：Cosmicube 解锁/商店系统未移植，
 * 这里只保留货币数值，让脚本的 `currentMoney += n` 不报错。
 */
class CosmicubeData
{
	public static var currentMoney(get, set):Int;

	/** 货币显示名（NMV 里来自 cosmicube 元数据）。 */
	public static var currentCurrency(get, never):String;

	public static var cosmicubeList:Array<String> = [];
	public static var cosmicubeMetas:Map<String, Dynamic> = [];
	public static var cosmicubeItems:Map<String, Array<Dynamic>> = [];

	static var _money:Int = 0;

	public static function reload(hard:Bool = true):Void {}

	static function get_currentMoney():Int
		return _money;

	static function set_currentMoney(value:Int):Int
		return _money = value;

	static function get_currentCurrency():String
		return 'Money';
}
