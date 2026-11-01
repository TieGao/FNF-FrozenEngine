package nmv.objects;

import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.math.FlxPoint;
import flixel.graphics.frames.FlxAtlasFrames;

import flxanimate.PsychFlxAnimate;
import flxanimate.animate.FlxSymbol;
import flxanimate.animate.FlxTimeline;

import backend.Paths;

/**
 * NMV funkin.objects.FunkinSprite 的 FE 等价物。
 *
 * 用 flxanimate 做基座（NMV 原版同为 FlxAnimate 子类），补样本实际用到的表面：
 * 链式构造、loadAtlas、playAnim、addAnimByPrefix/ByIndices、animOffsets 等。
 * 其余 API 由 FlxSprite/PsychFlxAnimate 原生提供。
 */
class FunkinSprite extends PsychFlxAnimate
{
	// NMV 的 flixel fork 在 FlxBasic 上有 zIndex / skew，语料舞台脚本直接用；
	// FE pin 的 flixel 6.2.0 没有，这里按 API 兼容补字段（无渲染语义：zIndex
	// 不参与排序、skew 不参与绘制，视觉差异按已知限制记录）。
	public var zIndex:Int = 0;
	public var skew:FlxPoint = FlxPoint.get();

	/**
	 * NMV flixel fork 的 `FlxSprite.useRenderTexture` / `_renderTextureDirty`（离屏缓存开关）。
	 * FE 没有对应实现，但**字段必须存在**：脚本里是链式赋值
	 * `bf.useRenderTexture = gf.useRenderTexture = dad.useRenderTexture = pet.useRenderTexture = bfIntro.useRenderTexture = true;`
	 * （doubletrouble.hx:279），HScript 的 `set` 走 `Reflect.setProperty`，hxcpp 对缺失字段抛
	 * `Invalid field:useRenderTexture` → **整条链从右往左第一项就炸**，onCreatePost 从 279 行
	 * 起全部中断：`red`（第三个角色）没被创建、灯光/camGame.filters/闪电全没跑，
	 * 之后每帧 `red.update(elapsed)` 在 null 上取字段 → 4129 行/局的刷屏
	 * （2026-11-01 bread.log 实测 `doubletrouble:496/537/547`）。
	 */
	public var useRenderTexture:Bool = false;
	/** 同上（NMV 的脏标记；这里只是可写字段，不驱动任何重绘）。 */
	public var _renderTextureDirty:Bool = false;

	/** 逐动画偏移，`playAnim` 时叠加到 `offset`。 */
	public var animOffsets:Map<String, Array<Float>> = [];

	/**
	 * NMV 语义：偏移随精灵缩放。FE 的 `offset` 本身不参与缩放，
	 * 这里只保留字段供脚本读写（skeldpixel 用它算像素对齐），无渲染差异。
	 */
	public var scalableOffsets:Bool = true;

	/** NMV：false 时 playAnim 失效（playAnimForDuration 的 force 用）。 */
	public var canPlayAnimations:Bool = true;

	/** 图集是 Sparrow/Packer 而不是 Animate（决定动画注册走哪条路）。 */
	var sparrowFrames:Bool = false;

	public function new(?x:Float = 0, ?y:Float = 0, ?graphic:FlxGraphicAsset = null)
	{
		super(x, y);

		if (graphic != null) loadGraphic(graphic);
	}

	/**
	 * 加载图集（NMV `loadAtlas` 的等价物，支持 `a,b` 多路径）。三种布局依次尝试：
	 * - Adobe Animate 布局（images/<path>/Animation.json + spritemap*.json/png）
	 * - Psych 的 spritemap 约定（images/<path>/spritemap.json）
	 * - Sparrow / Packer（images/<path>.xml|.json|.txt + .png），medbay、tablet 等舞台道具走这档
	 * 找不到图集只告警不抛：NMV 的 loadAtlas 对缺图集是容忍的（精灵无动画、脚本继续）。
	 *
	 * 不叫 loadAtlas：flxanimate 库的同名方法是 Adobe Animate 布局且返回 Void，
	 * 覆盖会撞签名；脚本里的 loadAtlas 调用由 InterpEx.fcall 特判转到这里。
	 */
	public function loadNmvAtlas(path:String):FunkinSprite
	{
		final paths:Array<String> = path.split(',');
		var loadedAny = false;

		for (rawPath in paths)
		{
			final p = rawPath.trim();
			if (p.length == 0) continue;

			final isAnimate = Paths.getTextFromFile('images/$p/spritemap.json') != null
				|| Paths.getTextFromFile('images/$p/Animation.json') != null;

			if (isAnimate)
			{
				if (!loadedAny)
				{
					Paths.loadAnimateAtlas(this, p);
					loadedAny = true;
				}
				else addExtraAtlas(p);
				continue;
			}

			if (Paths.fileExists('images/$p.xml', openfl.utils.AssetType.TEXT)
				|| Paths.fileExists('images/$p.json', openfl.utils.AssetType.TEXT)
				|| Paths.fileExists('images/$p.txt', openfl.utils.AssetType.TEXT))
			{
				final spar = Paths.getAtlas(p);
				if (spar == null) continue;

				sparrowFrames = true;
				// NMV 语义：sparrow 图集的 FunkinSprite 就是普通 FlxSprite 渲染——
				// 不设这个，draw 门卫会因 anim.curInstance 为 null 把整个精灵吞掉
				// （reactor 大球 coreGlow/coreRing/coreClaw 不可见的根因）
				allowPlainDraw = true;
				if (!loadedAny)
				{
					frames = spar;
					loadedAny = true;
				}
				else
				{
					final main:FlxAtlasFrames = cast frames;
					if (main != null) main.addAtlas(spar);
				}
			}
		}

		if (!loadedAny) flixel.FlxG.log.warn('FunkinSprite.loadAtlas("$path"): no atlas found under images/$path');

		return this;
	}

	/** 播放动画；force 决定是否重启动画。图集未加载时跳过（flxanimate 对空控制器 play 会裸 NPE）。 */
	public function playAnim(name:String, force:Bool = false, reversed:Bool = false, ?frame:Int = 0):Void
	{
		if (!canPlayAnimations) return;
		if (anim == null || anim.getByName(name) == null) return;

		anim.play(name, force, reversed, frame);

		final off = animOffsets.get(name);
		if (off != null) offset.set(off[0], off[1]);
	}

	/** 定义动画偏移（NMV 同名 API）。 */
	public function addOffset(anim:String, x:Float = 0, y:Float = 0):Void
	{
		animOffsets.set(anim, [x, y]);
	}

	/**
	 * NMV 的注册顺序：帧标签 → 符号（精确）→ 帧前缀。
	 *
	 * 旧库 `addBySymbol` 是前缀匹配 + 字典顺序取第一个（"black left" 会撞上
	 * "black left alt"），所以符号一档必须先用 `symbolDictionary.exists` 判精确名。
	 * flipX/flipY 在旧库里没有对应参数，忽略（语料未用到）。
	 */
	public function addAnimByPrefix(name:String, prefix:String, fps:Int = 24, looping:Bool = true, flipX:Bool = false, flipY:Bool = false):Void
	{
		if (anim == null) return;

		if (sparrowFrames)
		{
			addSparrowAnim(name, prefix, null, fps, looping);
			return;
		}

		var hasFrameLabel:Bool = false;
		try hasFrameLabel = anim.getFrameLabel(prefix) != null catch (e:Dynamic) {}

		if (hasFrameLabel)
			anim.addByFrameLabel(name, prefix, fps, looping);
		else if (anim.symbolDictionary != null && anim.symbolDictionary.exists(prefix))
			anim.addBySymbol(name, prefix, fps, looping);
		else if (frames != null)
			animation.addByPrefix(name, prefix, fps, looping, flipX, flipY);
		else
			anim.addBySymbol(name, prefix, fps, looping);
	}

	/** 同 `addAnimByPrefix`，走帧下标。 */
	public function addAnimByIndices(name:String, prefix:String, indices:Array<Int>, fps:Int = 24, looping:Bool = true, flipX:Bool = false,
			flipY:Bool = false):Void
	{
		if (anim == null || indices == null) return;

		if (sparrowFrames)
		{
			addSparrowAnim(name, prefix, indices, fps, looping);
			return;
		}

		var hasFrameLabel:Bool = false;
		try hasFrameLabel = anim.getFrameLabel(prefix) != null catch (e:Dynamic) {}

		if (anim.symbolDictionary != null && anim.symbolDictionary.exists(prefix))
			// 防环版：图集里可能有与动画名同名的子符号，原版 addBySymbolIndices 会无限递归
			safeAddBySymbolIndices(name, prefix, indices, fps, looping);
		else if (frames != null)
			animation.addByIndices(name, prefix, indices, '', fps, looping, flipX, flipY);
		else if (hasFrameLabel)
			anim.addByFrameLabel(name, prefix, fps, looping);
	}

	/**
	 * Sparrow / Packer 图集造动画。
	 *
	 * `FlxAnimate.draw()` 只画 `anim` 当前符号，不认 FlxSprite 的 animation 控制器，
	 * 所以帧必须包成一个符号注册进 anim（元素格式与 `addExtraAtlas` 的 sparrow 分支一致：
	 * 每帧一个元素、名字即帧名，`drawLimb` 用 `frames.getByName` 取图）。
	 */
	function addSparrowAnim(name:String, prefix:String, indices:Array<Int>, fps:Int, looping:Bool):Void
	{
		var matched:Array<String> = [];
		if (frames != null)
		{
			for (frame in frames.frames)
				if (frame.name != null && StringTools.startsWith(frame.name, prefix)) matched.push(frame.name);
		}
		matched.sort(Reflect.compare);

		if (indices != null && indices.length > 0)
		{
			var picked:Array<String> = [];
			for (i in indices)
				if (i >= 0 && i < matched.length) picked.push(matched[i]);
			matched = picked;
		}

		if (matched.length == 0)
		{
			flixel.FlxG.log.warn('FunkinSprite.addAnimByPrefix: no frame matches "$prefix"');
			return;
		}

		// NMV 语义（FunkinSprite:266-280）：非 Animate 图集的动画注册进标准 animation
		// 控制器——脚本的 coreGlow.animation.play('bop') 走的就是标准控制器，不注册
		// 这份 play 无效（帧虽画出、动画不播）。同帧序列双注册：flxanimate 侧保
		// getAnimName/curFrame 兼容，标准侧供实际播放。
		if (indices != null && indices.length > 0)
			animation.addByIndices(name, prefix, indices, '', fps, looping);
		else
			animation.addByPrefix(name, prefix, fps, looping);

		// 纯 Sparrow 图集（无 Animation.json）时 `anim.symbolDictionary` 是 **null**
		// （FlxAnim 只在 _loadAtlas 里初始化它），下面直接 set 会裸 NPE ——
		// 这就是 reactor:50 `coreGlow.addAnimByPrefix('bop','reactor core',…)`
		// 每次进歌必炸、onLoad 后半段（coreRing/coreClaw/overlay）全不建的根因。
		if (anim.symbolDictionary == null) anim.symbolDictionary = [];

		final key = '@sparrow:' + name;
		var contentFrames:Array<Dynamic> = [];
		for (i in 0...matched.length)
			contentFrames.push({I: i, DU: 1, E: [{ASI: {MX: [1, 0, 0, 1, 0, 0], N: matched[i]}}]});

		final timeline = FlxTimeline.fromJSONEx({L: [{LN: 'content', FR: contentFrames}]});
		if (timeline == null) return;

		anim.symbolDictionary.set(key, new FlxSymbol(key, timeline));
		anim.addBySymbol(name, key, fps, looping);
	}

	public inline function getAnimName():String
		return isAnimNull() ? '' : anim.curInstance.symbol.name;

	public function hasAnim(name:String):Bool
		return anim != null && anim.getByName(name) != null;

	public inline function isAnimNull():Bool
		return anim == null || anim.curInstance == null || anim.curSymbol == null;

	public inline function isAnimFinished():Bool
		return isAnimNull() ? false : anim.finished;

	public inline function pauseAnim():Void
		if (!isAnimNull()) anim.pause();

	public inline function resumeAnim():Void
		if (!isAnimNull()) anim.resume();

	public inline function getAnimNumFrames():Int
		return isAnimNull() ? 0 : anim.length;

	public var animCurFrame(get, set):Int;

	inline function get_animCurFrame():Int
		return isAnimNull() ? 0 : anim.curFrame;

	inline function set_animCurFrame(value:Int):Int
		return isAnimNull() ? 0 : (anim.curFrame = value);

	public function removeAnim(name:String):Void
	{
		@:privateAccess
		if (anim != null) anim.animsMap.remove(name);
		animOffsets.remove(name);
	}

	public function renameAnim(oldName:String, newName:String):Void
	{
		@:privateAccess
		if (anim != null)
		{
			final stuff = anim.animsMap.get(oldName);
			if (stuff != null)
			{
				anim.animsMap.remove(oldName);
				anim.animsMap.set(newName, stuff);
			}
		}
		final off = animOffsets.get(oldName);
		if (off != null)
		{
			animOffsets.set(newName, off);
			animOffsets.remove(oldName);
		}
	}
}
