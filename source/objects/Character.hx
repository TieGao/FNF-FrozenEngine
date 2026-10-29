package objects;

import backend.animation.PsychAnimationController;

import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;
import haxe.Json;
import haxe.DynamicAccess;

import backend.Song;
import states.stages.objects.TankmenBG;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	var vocals_file:String;
	@:optional var flags:Dynamic;
	@:optional var scalableOffsets:Null<Bool>;
	@:optional var healthbar_colour:Null<Int>;
	@:optional var gameover_character:String;
	@:optional var afterimages:Null<Bool>;
	@:optional var _editor_isPlayer:Null<Bool>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
	@:optional var flip_x:Bool; // atlas 专用：逐动画翻转（美术朝向不一致的图集用）
}

class Character extends FlxSprite
{
	/**
	 * In case a character is missing, it will use this on its place
	**/
	public static final DEFAULT_CHARACTER:String = 'bf';

	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; //Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; //Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var missingCharacter:Bool = false;
	public var missingText:FlxText;
	public var hasMissAnimations:Bool = false;
	public var vocalsFile:String = '';

	/** 角色 json 的 `flags`（NMV 的 isPixel / variants / backlit 等），脚本用 `getFlag` 读。 */
	public var flags:DynamicAccess<Dynamic> = {};

	/** NMV：偏移随角色缩放。FE 的 offset 不参与缩放，字段只为脚本读写保留。 */
	public var scalableOffsets:Bool = true;

	/**
	 * NMV：true 时 `updateHitbox()` 会把 offset 清零（NMV 的动画偏移在绘制期叠加，
	 * offset 另有用途）。FE 的动画偏移就存在 offset 上，清零会丢偏移，所以这里只保留
	 * 字段、不实现清零行为；脚本用 `legacyOffset = false` 表达的"别动我的偏移"正好成立。
	 */
	public var legacyOffset:Bool = true;

	/** NMV：false 时不再自动跳舞（语料在剧情段临时关掉）。 */
	public var canDance:Bool = true;

	/** NMV：允许嘲讽（按嘲讽键播 'hey'）；语料只写这个开关（d'low.hx），按键玩法未移植。 */
	public var canTaunt:Bool = true;

	/** NMV 兼容（bf-running 写 parent.baseFlipX）：偏移翻转修正的基准朝向 = 出生时的 flipX（NMV Character 同公式）。 */
	public var baseFlipX:Null<Bool> = null;
	public var baseFlipY:Null<Bool> = null;

	/** NMV setAnimOffset 翻转修正的基准帧宽（首次施加偏移且图集就绪时采样）。 */
	public var baseFrameWidth:Float = -1;
	public var baseFrameHeight:Float = -1;

	/** 血量条颜色（NMV 用单个整数，json 键 `healthbar_colour`）。 */
	public var healthColour:Int = 0xFFA1A1A1;

	/** 死亡角色名（json 键 `gameover_character`）；FE 的死亡演出不读这个字段，仅脚本读写。 */
	public var gameoverCharacter:String = '';

	/** 残影开关（NMV 的 afterimages）；FE 未移植残影系统，字段仅供脚本读写。 */
	public var ghostsEnabled:Bool = false;

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	/** atlas 专用：逐动画翻转（json 动画条目可选字段 `flip_x`），解决同一图集内美术朝向不一致 */
	public var animFlipXMap:Map<String, Bool> = new Map();
	/** 当前动画的逐动画翻转状态（copyAtlasValues 时与整体 flipX 异或） */
	public var animFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false)
	{
		super(x, y);

		animation = new PsychAnimationController(this);

		animOffsets = new Map<String, Array<Dynamic>>();
		this.isPlayer = isPlayer;
		changeCharacter(character);
		
		switch(curCharacter)
		{
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
			case 'pico-blazin', 'darnell-blazin':
				skipDance = true;
		}
	}

	public function changeCharacter(character:String)
	{
		animationsArray = [];
		animOffsets = [];
		#if flxanimate
		nmvAnchorReady = false;
		#end
		curCharacter = character;
		var characterPath:String = 'characters/$character.json';

		var path:String = Paths.getPath(characterPath, TEXT);
		#if MODS_ALLOWED
		if (!FileSystem.exists(path))
		#else
		if (!Assets.exists(path))
		#end
		{
			path = Paths.getSharedPath('characters/' + DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
			missingCharacter = true;
			missingText = new FlxText(0, 0, 300, 'ERROR:\n$character.json', 16);
			missingText.alignment = CENTER;
		}

		try
		{
			#if MODS_ALLOWED
			loadCharacterFile(Json.parse(File.getContent(path)));
			#else
			loadCharacterFile(Json.parse(Assets.getText(path)));
			#end
		}
		catch(e:Dynamic)
		{
			trace('Error loading character file of "$character": $e');
		}

		skipDance = false;
		hasMissAnimations = hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss');
		//trace('hasMiss=$hasMissAnimations  keys=' + [for (k in animOffsets.keys()) k]);
		recalculateDanceIdle();
		dance();
	}

	public function loadCharacterFile(json:Dynamic)
	{
		isAnimateAtlas = false;

		#if flxanimate
		nmvAtlasAnchorFix = false;
		var animToFind:String = Paths.getPath('images/' + json.image + '/Animation.json', TEXT);
		if (#if MODS_ALLOWED FileSystem.exists(animToFind) || #end Assets.exists(animToFind))
			isAnimateAtlas = true;

		// 锚点补偿默认关闭：首帧采样不准，先按角色 json 显式开启（"atlas_anchor": "nmv"）
		var anchorMode:String = json.atlas_anchor;
		nmvAtlasAnchorFix = (anchorMode == 'nmv');
		#end

		scale.set(1, 1);
		updateHitbox();

		if(!isAnimateAtlas)
		{
			frames = Paths.getMultiAtlas(json.image.split(','));
		}
		#if flxanimate
		else
		{
			atlas = new FlxAnimate();
			atlas.showPivot = false;
			try
			{
				backend.Bread.crumb('char[' + curCharacter + '] atlas begin ' + json.image);
				Paths.loadAnimateAtlas(atlas, json.image);
				backend.Bread.crumb('char[' + curCharacter + '] atlas parsed');

				// 逐动画的额外图集（原版 `multianimateatlas`：死亡 / 变体动画常放在另一张分尸图里）。
				// 引擎的角色 json 只有 `image` 一个字段，所以额外图集写在动画条目自己的 `assetPath` 上，
				// 这里收集去重后逐份并进来。
				var extraAtlasPaths:Array<String> = [];
				var rawAnims:Array<Dynamic> = cast json.animations;
				if (rawAnims != null)
				{
					for (anim in rawAnims)
					{
						var extra:String = anim.assetPath;
						if (extra == null || extra.length < 1 || extraAtlasPaths.contains(extra)) continue;
						extraAtlasPaths.push(extra);
					}
				}
				for (extra in extraAtlasPaths)
				{
					backend.Bread.crumb('char[' + curCharacter + '] extra atlas ' + extra);
					atlas.addExtraAtlas(extra);
					backend.Bread.crumb('char[' + curCharacter + '] extra atlas done');
				}
				backend.Bread.crumb('char[' + curCharacter + '] atlas ok');
			}
			catch(e:haxe.Exception)
			{
				FlxG.log.warn('Could not load atlas ${json.image}: $e');
				trace(e.stack);
			}
		}
		#end

		imageFile = json.image;
		jsonScale = json.scale;
		if(json.scale != 1) {
			scale.set(jsonScale, jsonScale);
			updateHitbox();
		}

		// positioning
		positionArray = json.position;
		cameraPosition = json.camera_position;

		// data
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = (json.flip_x != isPlayer);
		// NMV Character 同款基准：偏移翻转修正用它判断 flipX 是否偏离出生朝向
		baseFlipX = flipX;
		healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];
		vocalsFile = json.vocals_file != null ? json.vocals_file : '';
		originalFlipX = (json.flip_x == true);
		editorIsPlayer = json._editor_isPlayer;
		flags = (json.flags != null) ? json.flags : {};
		scalableOffsets = (json.scalableOffsets != null) ? json.scalableOffsets : true;
		healthColour = (json.healthbar_colour != null) ? json.healthbar_colour : FlxColor.fromRGB(healthColorArray[0], healthColorArray[1],
			healthColorArray[2]);
		gameoverCharacter = (json.gameover_character != null) ? json.gameover_character : '';
		ghostsEnabled = (json.afterimages == true);

		// antialiasing
		noAntialiasing = (json.no_antialiasing == true);
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;
		if(animationsArray != null && animationsArray.length > 0) {
			for (anim in animationsArray) {
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop:Bool = !!anim.loop; //Bruh
				var animIndices:Array<Int> = anim.indices;

				if(!isAnimateAtlas)
				{
					if(animIndices != null && animIndices.length > 0)
						animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
					else
						animation.addByPrefix(animAnim, animName, animFps, animLoop);
				}
				#if flxanimate
				else
				{
					// 旧库 addBySymbol 是"前缀匹配 + 字典顺序取第一个"："black left" 会撞上
					// "black left alt"、"black" 会撞上 "black up" → 动画内容串台、长符号一直循环。
					// 与 NMV 的 addAnimByPrefix 同序：帧标签 → 符号（精确）→ 前缀。
					var hasFrameLabel:Bool = false;
					try hasFrameLabel = atlas.anim.getFrameLabel(animName) != null catch(e:Dynamic) {}

					// 优先级（实证校准）：带 indices 的动画必须走 indices——gf 的
					// danceLeft/danceRight 是同一符号 'GF Dancing Beat' 靠 indices 分段，
					// 若被精确符号/帧标签抢先注册成整段符号，GF 只会单向摆头。
					// 其次帧标签，再次精确符号（防 addBySymbol 前缀匹配串台：
					// 'black left' 撞 'black left alt'），最后才是前缀兜底。
					if(animIndices != null && animIndices.length > 0)
						atlas.safeAddBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					else if(hasFrameLabel)
						atlas.anim.addByFrameLabel(animAnim, animName, animFps, animLoop);
					else if(atlas.anim.symbolDictionary != null && atlas.anim.symbolDictionary.exists(animName))
						atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
					// 防环版：图集里可能有与动画名同名的子符号（kazuha 的 idle），
					// 原版 addBySymbolIndices 会覆盖它造成渲染期无限递归 → 栈溢出闪退
					else
						atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
					// 逐动画翻转（tankman 的 basic 包 idle/sing 与 extra 包美术朝向不一致）
					animFlipXMap.set(animAnim, (anim.flip_x == true));
				}
				#end

				if(anim.offsets != null && anim.offsets.length > 1) addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				else addOffset(anim.anim, 0, 0);
			}
		}
		#if flxanimate
		if(isAnimateAtlas) copyAtlasValues();
		#end
		//trace('Loaded file to character ' + curCharacter);
	}

	override function update(elapsed:Float)
	{
		if(isAnimateAtlas) atlas.update(elapsed);

		if(debugMode || (!isAnimateAtlas && animation.curAnim == null) || (isAnimateAtlas && (atlas.anim.curInstance == null || atlas.anim.curSymbol == null)))
		{
			super.update(elapsed);
			return;
		}

		if(heyTimer > 0)
		{
			var rate:Float = (PlayState.instance != null ? PlayState.instance.playbackRate : 1.0);
			heyTimer -= elapsed * rate;
			if(heyTimer <= 0)
			{
				var anim:String = getAnimationName();
				if(specialAnim && (anim == 'hey' || anim == 'cheer'))
				{
					specialAnim = false;
					dance();
				}
				heyTimer = 0;
			}
		}
		else if(specialAnim && isAnimationFinished())
		{
			specialAnim = false;
			dance();
		}
		else if (getAnimationName().endsWith('miss') && isAnimationFinished())
		{
			dance();
			finishAnimation();
		}

		switch(curCharacter)
		{
			case 'pico-speaker':
				if(animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
				{
					var noteData:Int = 1;
					if(animationNotes[0][1] > 2) noteData = 3;

					noteData += FlxG.random.int(0, 1);
					playAnim('shoot' + noteData, true);
					animationNotes.shift();
				}
				if(isAnimationFinished()) playAnim(getAnimationName(), false, false, animation.curAnim.frames.length - 3);
		}

		if (getAnimationName().startsWith('sing')) holdTimer += elapsed;
		else if(isPlayer) holdTimer = 0;

		if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		var name:String = getAnimationName();
		if(isAnimationFinished() && hasAnimation('$name-loop'))
			playAnim('$name-loop');

		super.update(elapsed);
	}

	inline public function isAnimationNull():Bool
	{
		return !isAnimateAtlas ? (animation.curAnim == null) : (atlas.anim.curInstance == null || atlas.anim.curSymbol == null);
	}

	var _lastPlayedAnimation:String;
	inline public function getAnimationName():String
	{
		return _lastPlayedAnimation;
	}

	public function isAnimationFinished():Bool
	{
		if(isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.finished : atlas.anim.finished;
	}

	public function finishAnimation():Void
	{
		if(isAnimationNull()) return;

		if(!isAnimateAtlas) animation.curAnim.finish();
		else atlas.anim.curFrame = atlas.anim.length - 1;
	}

	public function hasAnimation(anim:String):Bool
	{
		return animOffsets.exists(anim);
	}

	public var animPaused(get, set):Bool;
	private function get_animPaused():Bool
	{
		if(isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.paused : atlas.anim.isPlaying;
	}
	private function set_animPaused(value:Bool):Bool
	{
		if(isAnimationNull()) return value;
		if(!isAnimateAtlas) animation.curAnim.paused = value;
		else
		{
			if(value) atlas.pauseAnimation();
			else atlas.resumeAnimation();
		}

		return value;
	}

	public var danced:Bool = false;

	// NMV 兼容面（Bopper API）：字段/方法存在、语义降级为桩，避免角色脚本 onLoad 中断
	public var useRenderTexture:Bool = false;

	/** NMV 角色脚本直接调 char.onBeatHit(curBeat)；FE 的跳舞走 PlayState beatHit → dance()，这里不重复触发。 */
	public function onBeatHit(curBeat:Int):Void {}

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance()
	{
		if (!debugMode && !skipDance && !specialAnim && canDance)
		{
			if(danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight' + idleSuffix);
				else
					playAnim('danceLeft' + idleSuffix);
			}
			else if(hasAnimation('idle' + idleSuffix))
				playAnim('idle' + idleSuffix);
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		if(!isAnimateAtlas)
		{
			animation.play(AnimName, Force, Reversed, Frame);
		}
		else
		{
			atlas.anim.play(AnimName, Force, Reversed, Frame);
			atlas.update(0);
			animFlipX = (animFlipXMap.get(AnimName) == true);
		}
		_lastPlayedAnimation = AnimName;

		if (hasAnimation(AnimName))
		{
			var daOffset = animOffsets.get(AnimName);
			#if flxanimate
			// NMV setAnimOffset 的翻转修正：翻转态下 X 偏移按帧宽镜像
			// （red 作为玩家侧被翻转后裸用 json 偏移，每个唱击动作横向甩 500px+ = "漂移"）。
			// 基准帧宽首次就绪时采样；图集未就绪（-1）先按裸值。
			if (isAnimateAtlas && baseFrameWidth < 0 && frameWidth > 0)
			{
				baseFrameWidth = frameWidth;
				baseFrameHeight = frameHeight;
			}
			if (isAnimateAtlas && baseFrameWidth >= 0)
			{
				offset.set(
					(baseFlipX != null && flipX != baseFlipX) ? (frameWidth - baseFrameWidth - daOffset[0]) : daOffset[0],
					(baseFlipY != null && flipY != baseFlipY) ? (frameHeight - baseFrameHeight - daOffset[1]) : daOffset[1]
				);
			}
			else
			#end
				offset.set(daOffset[0], daOffset[1]);
		}
		//else offset.set(0, 0);

		#if flxanimate
		// Animate 图集的锚点补偿对所有动画一致，切动画时重新叠加，避免被 animOffsets 覆盖掉
		if(nmvAtlasAnchorFix && nmvAnchorReady)
		{
			offset.x += nmvAnchorDx;
			offset.y += nmvAnchorDy;
		}
		#end

		if (curCharacter.startsWith('gf-') || curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
				danced = true;

			else if (AnimName == 'singRIGHT')
				danced = false;

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}

	function loadMappedAnims():Void
	{
		try
		{
			var songData:SwagSong = Song.getChart('picospeaker', Paths.formatToSongPath(Song.loadedSongName));
			if(songData != null)
				for (section in songData.notes)
					for (songNotes in section.sectionNotes)
						animationNotes.push(songNotes);

			TankmenBG.animationNotes = animationNotes;
			animationNotes.sort(sortAnims);
		}
		catch(e:Dynamic) {}
	}

	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	public var danceEveryNumBeats:Int = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix));

		if(settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		}
		else if(lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if(danceIdle)
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		animation.addByPrefix(name, anim, 24, false);
	}

	public function hasFlag(flag:String):Bool
	{
		return flags != null && flags.exists(flag);
	}

	/**
	 * NMV：当前帧的读写口（bf-running 用 legs.animCurFrame 对齐两套动画的帧）。
	 * 语义与 NMV FunkinSprite 一致：无动画时读 0、写丢弃。
	 */
	public var animCurFrame(get, set):Int;

	inline function get_animCurFrame():Int
	{
		return (animation == null || animation.curAnim == null) ? 0 : animation.curAnim.curFrame;
	}

	inline function set_animCurFrame(value:Int):Int
	{
		if (animation != null && animation.curAnim != null) animation.curAnim.curFrame = value;
		return value;
	}

	/** NMV 的角色 flag 读取；没有该 flag 时返回 null（脚本常写 `getFlag('x') != true`）。 */
	public function getFlag(flag:String):Dynamic
	{
		return (flags == null) ? null : flags.get(flag);
	}

	/** NMV 名（`getAnimationName` 的别名）。 */
	inline public function getAnimName():String
		return getAnimationName();

	/** NMV 名（`hasAnimation` 的别名）。 */
	inline public function hasAnim(name:String):Bool
		return hasAnimation(name);

	/** 改名一个已注册的动画（NMV 的 turbulence 舞台用临时名做动画替换）。 */
	public function renameAnim(oldName:String, newName:String):Void
	{
		final off = animOffsets.get(oldName);
		animation.rename(oldName, newName);
		if (off != null)
		{
			animOffsets.set(newName, off);
			animOffsets.remove(oldName);
		}
	}

	// Atlas support
	// special thanks ne_eo for the references, you're the goat!!
	@:allow(states.editors.CharacterEditorState)
	public var isAnimateAtlas(default, null):Bool = false;
	#if flxanimate
	public var atlas:FlxAnimate;

	/**
	 * NMV 内容包的 Animate 图集锚点补偿开关。
	 * 旧 flxanimate 以 Animate 舞台原点定锚，NMV 用的 flixel-animate 以时间轴包围盒左上角定锚，
	 * 同一份 Animation.json 在两边会整体错开包围盒的 (x, y)。
	 */
	public var nmvAtlasAnchorFix:Bool = false;
	/**
	 * 锚点补偿量（舞台坐标 → 包围盒锚点），首次绘制时采样一次后全局固定。
	 * 必须所有动画共用同一个值：flixel-animate 用的是整条时间轴的包围盒，
	 * 逐动画各算一个会让切换动画时角色跳位。
	 */
	var nmvAnchorDx:Float = 0;
	var nmvAnchorDy:Float = 0;
	var nmvAnchorReady:Bool = false;

	public override function draw()
	{
		var lastAlpha:Float = alpha;
		var lastColor:FlxColor = color;
		if(missingCharacter)
		{
			alpha *= 0.6;
			color = FlxColor.BLACK;
		}

		if(isAnimateAtlas)
		{
			if(atlas.anim.curInstance != null)
			{
				copyAtlasValues();
				atlas.draw();
				if(nmvAtlasAnchorFix) captureNmvAnchor();
				alpha = lastAlpha;
				color = lastColor;
				if(missingCharacter && visible)
				{
					missingText.x = getMidpoint().x - 150;
					missingText.y = getMidpoint().y - 10;
					missingText.draw();
				}
			}
			return;
		}
		super.draw();
		if(missingCharacter && visible)
		{
			alpha = lastAlpha;
			color = lastColor;
			missingText.x = getMidpoint().x - 150;
			missingText.y = getMidpoint().y - 10;
			missingText.draw();
		}
	}

	public function copyAtlasValues()
	{
		@:privateAccess
		{
			atlas.cameras = cameras;
			atlas.scrollFactor = scrollFactor;
			atlas.scale = scale;
			atlas.offset = offset;
			atlas.origin = origin;
			atlas.x = x;
			atlas.y = y;
			atlas.angle = angle;
			atlas.alpha = alpha;
			atlas.visible = visible;
			atlas.flipX = (flipX != animFlipX);
			atlas.flipY = flipY;
			atlas.shader = shader;
			atlas.antialiasing = antialiasing;
			atlas.colorTransform = colorTransform;
			atlas.color = color;
		}
	}

	/**
	 * 首帧绘制后采样一次锚点偏移，全局固定。
	 * 不预遍历所有动画：那需要额外 atlas.draw()，部分角色在相机/图集未就绪时段错误闪退；
	 * relativeX/Y 是屏幕空间值，加回相机滚动和 offset 才是舞台坐标下的内容位置。
	 */
	function captureNmvAnchor():Void
	{
		if(nmvAnchorReady) return;
		if(atlas.frameWidth <= 0 || atlas.frameHeight <= 0) return;

		var cam = atlas.camera;
		var sf = atlas.scrollFactor;
		nmvAnchorDx = atlas.relativeX + (cam != null ? cam.scroll.x * sf.x : 0) + atlas.offset.x;
		nmvAnchorDy = atlas.relativeY + (cam != null ? cam.scroll.y * sf.y : 0) + atlas.offset.y;
		nmvAnchorReady = true;

		offset.x += nmvAnchorDx;
		offset.y += nmvAnchorDy;
		backend.Bread.crumb('nmv anchor ' + curCharacter + ' dx=' + Std.int(nmvAnchorDx) + ' dy=' + Std.int(nmvAnchorDy));
	}

	public override function destroy()
	{
		atlas = FlxDestroyUtil.destroy(atlas);
		super.destroy();
	}
	#end
}
