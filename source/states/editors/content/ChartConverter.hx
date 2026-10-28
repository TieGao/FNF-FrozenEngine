package states.editors.content;

import backend.Song;
import states.editors.content.ChartConvertCore.ChartImportInfo;

/**
 * FE 侧的统一谱面转换门面：其他游戏格式 → SwagSong，以及 SwagSong → 其他游戏格式。
 * 纯转换逻辑在 ChartConvertCore（只依赖 moonchart，可脱离引擎独立测试），
 * 这里只做引擎类型封装。解析/生成失败直接抛错，由调用方（ChartingState）catch 后展示。
 */
class ChartConverter
{
	public static var FILE_FILTER(get, never):String;
	public static var EXPORT_FORMATS(get, never):Array<String>;

	static inline function get_FILE_FILTER():String
	{
		return ChartConvertCore.FILE_FILTER;
	}

	static inline function get_EXPORT_FORMATS():Array<String>
	{
		return ChartConvertCore.EXPORT_FORMATS;
	}

	/**
	 * 识别文件格式（sm/ssc/osu/osz/qua/qp/mid/mc），不认识返回 null
	 */
	public static function detectFormat(path:String):Null<String>
	{
		return ChartConvertCore.detectFormat(path);
	}

	/**
	 * 探测文件信息（格式/键数/难度列表/标题），供导入对话框使用
	 */
	public static function probe(path:String):ChartImportInfo
	{
		return ChartConvertCore.probe(path);
	}

	/**
	 * 导入为 SwagSong
	 * @param diff 源难度名（null = 第一个难度）
	 * @param targetKeys 目标键数；与源键数不同时按比例重排列
	 */
	public static function importChart(path:String, ?diff:String, targetKeys:Int = 4):SwagSong
	{
		return cast ChartConvertCore.importToSong(path, diff, targetKeys);
	}

	/**
	 * 导出为外部格式文本（.sm / .ssc / .osu / .qua）
	 * @param diffName 写入文件的难度名（如 Challenge）
	 */
	public static function exportChart(song:SwagSong, format:String, diffName:String = 'Challenge'):String
	{
		return ChartConvertCore.exportFromSong(song, format, diffName);
	}
}
