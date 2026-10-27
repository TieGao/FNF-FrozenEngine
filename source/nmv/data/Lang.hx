package nmv.data;

import haxe.DynamicAccess;
import haxe.Json;

#if sys
import sys.FileSystem;
#end

import backend.Paths;
import backend.ClientPrefs;

/**
 * NMV funkin.data.Lang 移植：语言包查找与 str/hasSpecial/flags 的完整 API。
 *
 * 与 NMV 的差异：NMV 走 FunkinAssets + Mods.enabled 多目录合并，这里按 NMVMODS
 * 布局探候选 —— 当前包 <root>/lang/、共享层 content/NMVMODS/lang/、其余包的
 * lang/（当前包优先）。语言文件在发行版 content/lang/，用户已放进 NMVMODS/lang。
 */
typedef LanguageRaw =
{
	var ?name:String;
	var ?special:Array<String>;
	var ?flags:DynamicAccess<Dynamic>;
	var translation_credits:String;
	var lang:DynamicAccess<String>;
	var ?font_replacement:DynamicAccess<String>;
}

@:structInit class Language
{
	public var name:Null<String> = null;

	public var special:Null<Array<String>> = null;

	public var translationCredits:String = '';

	public var lang:Map<String, String> = [];

	public var flags:Map<String, String> = [];

	public var fontReplacements:Null<Map<String, String>> = null;

	public static function fromRaw(raw:Null<LanguageRaw>):Null<Language>
	{
		if (raw == null) return null;
		var lang:Language = {};

		lang.name = raw.name;
		lang.special = raw.special;
		lang.translationCredits = raw.translation_credits;
		lang.lang = [for (key => text in raw.lang) key => text];

		if (raw.flags != null) lang.flags = [for (key => text in raw.flags) key => text];
		if (raw.font_replacement != null) lang.fontReplacements = [for (key => text in raw.font_replacement) key => text];

		return lang;
	}
}

@:nullSafety(Off)
class Lang
{
	public static var current:Null<Language> = null;
	public static var fallback:Null<Language> = null;

	static var defaultLanguage:String = 'english';

	public static function reloadLangFile():Void
	{
		fallback = loadLang(defaultLanguage);

		final pref:Null<String> = Reflect.hasField(ClientPrefs.data, 'language') ? Reflect.field(ClientPrefs.data, 'language') : null;
		current = (pref == null || pref == defaultLanguage ? fallback : loadLang(pref));
	}

	public static function loadLang(lang:String):Null<Language>
	{
		var mergedLang:Null<LanguageRaw> = null;

		for (path in langCandidates(lang))
		{
			if (!FileSystem.exists(path)) continue;
			try
			{
				mergedLang = mergeRaw(mergedLang, Json.parse(sys.io.File.getContent(path)));
			}
			catch (e:Dynamic)
			{
				Sys.println('[NMV Lang] failed to parse $path: $e');
			}
		}

		if (mergedLang == null) trace('[NMV Lang] couldn\'t find "$lang" json');

		return (mergedLang == null || mergedLang.name == null ? null : Language.fromRaw(mergedLang));
	}

	/** 当前包 → 共享层（content/NMVMODS/lang）→ 其余包，与全局脚本的并集语义一致。 */
	static function langCandidates(lang:String):Array<String>
	{
		final out:Array<String> = [];
		final root:String = Paths.currentContentRoot;

		if (root != null && root.length > 0) out.push('$root/lang/$lang.json');
		out.push('content/NMVMODS/lang/$lang.json');

		if (root != null && root.indexOf('/NMVMODS/') != -1)
		{
			for (mod in backend.NMVContentData.listMods())
			{
				final p = 'content/NMVMODS/$mod/lang/$lang.json';
				if (out.indexOf(p) == -1) out.push(p);
			}
		}
		return out;
	}

	/** NMV CoolUtil.merge 的薄替代：后读的字段覆盖先读的。 */
	static function mergeRaw(base:Null<LanguageRaw>, over:LanguageRaw):LanguageRaw
	{
		if (base == null) return over;
		final out:LanguageRaw = cast Reflect.copy(base);
		for (field in Reflect.fields(over))
			Reflect.setField(out, field, Reflect.field(over, field));
		return out;
	}

	public static inline function getFont(fnt:String):String
	{
		return current == null || current.fontReplacements == null ? fnt : (current.fontReplacements.get(fnt) ?? fnt);
	}

	public static inline function hasSpecial(flag:String):Bool
	{
		final s = current == null ? null : current.special;
		return s != null ? s.contains(flag) : false;
	}

	public static inline function hasFlag(flag:String):Bool
	{
		final src = current ?? fallback;
		return src != null && src.flags.exists(flag);
	}

	public static inline function getFlag(flag:String):Dynamic
	{
		final src = current ?? fallback;
		return src == null ? null : src.flags.get(flag);
	}

	/**
	 * For RTL languages, reverses the line order of multiline FlxText.
	 * Fixes visual-order Arabic text getting wrapped with lines in wrong reading order.
	 */
	public static function arabicTextFix(textObj:flixel.text.FlxText):Void
	{
		if (!hasSpecial('rightToLeft')) return;

		var tf = textObj.textField;
		if (tf.numLines <= 1) return;

		var lines:Array<String> = [];
		for (i in 0...tf.numLines)
		{
			lines.push(StringTools.rtrim(tf.getLineText(i)));
		}
		lines.reverse();
		textObj.text = lines.join("\n");
	}

	/**
	 * Gets a string from said language!
	 * if string doesn't exist in selected language, tries to receieve it from english, and if english doesn't have it, return [MISSING `line`] instead
	 */
	public static inline function str(line:String, ?fallbackString:String):Null<String>
	{
		return (current == null ? null : current.lang.get(line))
			?? (fallback == null ? null : fallback.lang.get(line))
			?? fallbackString
			?? '<MISSING_$line>';
	}
}
