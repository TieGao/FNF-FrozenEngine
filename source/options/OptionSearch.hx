package options;

import options.Option;
import options.objects.OptionCategory;

/**
 * 设置搜索的统一匹配 / 统计工具。
 *
 * - 主界面 OptionsState：统计每个大类里有多少个选项命中，显示在卡片徽标上；
 * - 分类页 OptionsPageState：统计每个子分类里有多少个选项命中，显示在导航徽标上。
 *
 * 两边共用这里的匹配规则，保证搜索口径完全一致（改一处即可全局生效）。
 */
class OptionSearch
{
	/** 归一化查询串（去首尾空格 + 转小写）；返回空串表示"当前没有搜索" */
	public static function normalize(query:String):String
	{
		return (query == null) ? '' : query.trim().toLowerCase();
	}

	/** 查询串是否为空（等价于"未搜索"） */
	public static function isBlank(query:String):Bool
	{
		return normalize(query).length == 0;
	}

	/** 单个选项是否命中查询 */
	public static function matches(opt:Option, query:String):Bool
	{
		if (opt == null || query == null || query.length == 0) return false;

		var owner = opt.ownerCategory;
		var ownerText = (owner != null)
			? [owner.id, owner.displayName, owner.rawDisplayName].join(' ')
			: '';

		var haystack = [
			opt.name,
			opt.description,
			opt.variable,
			ownerText,
			opt.actionLabel
		].join(' ').toLowerCase();

		return haystack.indexOf(query) >= 0;
	}

	/** 一个分类（含其所有子分类）里命中的选项数 */
	public static function countInCategory(cat:OptionCategory, query:String):Int
	{
		if (cat == null || query == null || query.length == 0) return 0;

		var total = 0;
		for (opt in cat.allOptions())
			if (matches(opt, query)) total++;

		return total;
	}

	/**
	 * 每个子分类命中的选项数，顺序与 cat.subCategories 一一对应。
	 * 分类没有子分类时返回 [该分类总数]（和 OptionsPageState 的导航退化逻辑保持一致）。
	 */
	public static function countsPerSub(cat:OptionCategory, query:String):Array<Int>
	{
		var out:Array<Int> = [];
		if (cat == null || query == null || query.length == 0) return out;

		var subs = cat.subCategories;
		if (subs.length == 0)
		{
			out.push(countInCategory(cat, query));
			return out;
		}

		for (sub in subs)
			out.push(countInCategory(sub, query));

		return out;
	}

	/** 收集一个分类（含子分类）里所有命中的选项，顺序与 allOptions() 一致 */
	public static function filterCategory(cat:OptionCategory, query:String):Array<Option>
	{
		var out:Array<Option> = [];
		if (cat == null || query == null || query.length == 0) return out;

		for (opt in cat.allOptions())
			if (matches(opt, query)) out.push(opt);

		return out;
	}
}
