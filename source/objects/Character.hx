package objects;

import backend.animation.PsychAnimationController;

import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxRect;

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
	@:optional var gameover_loop_sound:String;
	/**
	 * **注意拼写**：NMV 的 `CharacterData` 里这个键就叫 `gameover_intial_sound`
	 * （少一个 i，mod 侧语料 137 个角色全用这个拼法），照抄别"顺手改正"。
	 */
	@:optional var gameover_intial_sound:String;
	@:optional var gameover_confirm_sound:String;
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

	/**
	 * NMV `FunkinSprite.rotatableOffsets`（`FunkinSprite.hx:44`，默认 true）：
	 * 角色 `angle != 0` 时，动画偏移跟着旋转（`setOffsets` 里 `point.rotateByDegrees(angle)`）。
	 *
	 * 这里只保留字段、不实现旋转：FE 的偏移是 `offset`（轴对齐），旋转偏移要连带改
	 * `NmvAtlasAnchor` 的 offsets 口径，风险大于收益。写它的语料只有一处——
	 * turbulence.hx:102 `boyfriend.rotatableOffsets = false`（把 bf 摆成被爪子抓住的 -90°），
	 * **缺字段时那行是写路径 → 抛 `Invalid field` → `evil()` 整段中断**（bf 不会被摆到爪子上、
	 * 也不会 angle=-90）。bf 的 animOffsets 全是 0，所以"旋转与否"本来就没有视觉差别。
	 */
	public var rotatableOffsets:Bool = true;

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

	/** 死亡角色名（json 键 `gameover_character`），由 `GameOverSubstate.new(playStateBoyfriend)` 消费
	 *  （NMV 语义：死亡角色由**玩家角色**的角色 json 决定，不是谱面 gameOverChar）。 */
	public var gameoverCharacter:String = '';

	/** NMV 兼容：死亡循环音乐名（json 键 `gameover_loop_sound`；turbulence 舞台脚本直接写
	 *  `Jorsawsee_Loop`）。消费端 = `GameOverSubstate.new(playStateBoyfriend)` → `loopSoundName`。 */
	public var gameoverLoopDeathSound:Null<String> = null;

	/** NMV 兼容：死亡确认音乐名（json 键 `gameover_confirm_sound`）。消费端同上 → `endSoundName`。 */
	public var gameoverConfirmDeathSound:Null<String> = null;

	/** NMV 兼容：死亡首音效（json 键 `gameover_intial_sound`，**mod 侧就拼成 intial**；
	 *  defeat 舞台脚本也会直接写）。消费端同上 → `deathSoundName`。
	 *  语料 13 个角色有这个值：`stage/ejected_death`（bf-fall）、`loss_ejected`（bf-fall-dead）、
	 *  `stage/defeat_kill_sfx`、`stage/stickbf_Death`、`stage/fnf_loss_sfx-pixel`、`stage/idk_death` 等。 */
	public var gameoverInitialDeathSound:Null<String> = null;

	/** NMV Bopper 面的相机跟唱位移幅度（utils.hx onMoveCamera 每次换镜头读）。 */
	public var camDisplacement:Float = 20;

	/** NMV 兼容（Character.getSingDisplacement，NMV:394）：按当前 sing 方向给镜头微位移。
	 *  此前缺失 → utils.hx:146 fcall 报 Unknown function → onMoveCamera 后半截中断。 */
	public function getSingDisplacement():flixel.math.FlxPoint
	{
		final animName:String = getAnimationName();
		if (animName.length < 5) return flixel.math.FlxPoint.weak();
		return switch (animName.substr(4).split('-')[0].toLowerCase())
		{
			case 'up': flixel.math.FlxPoint.weak(0, -camDisplacement);
			case 'down': flixel.math.FlxPoint.weak(0, camDisplacement);
			case 'left': flixel.math.FlxPoint.weak(-camDisplacement, 0);
			case 'right': flixel.math.FlxPoint.weak(camDisplacement, 0);
			default: flixel.math.FlxPoint.weak();
		}
	}

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
		nmvContentChar = false;
		nmvLoggedOffsets = [];
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

		#if flxanimate
		// NMV 语料（content/NMVMODS/<mod>）出品的角色：图集锚点补偿只对这批开
		// （FE 原生 atlas 角色的导出以舞台原点定锚，套用会把 tankman 之类整体挪位）。
		var normPath:String = path.replace('\\', '/');
		nmvContentChar = normPath.indexOf('/NMVMODS/') != -1;
		#end

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

		// 锚点补偿：NMV 语料角色默认开（语料 json 都不带 atlas_anchor，10-28 实测即无条件开、
		// 位置正确；d097ee11 改成 json 显式开启等于全关，位置才全线跑飞）。
		// json 里 'fe'/'none' 可关掉；FE 原生角色不受影响。
		var anchorMode:String = json.atlas_anchor;
		nmvAtlasAnchorFix = isAnimateAtlas
			&& (anchorMode == 'nmv' || (nmvContentChar && anchorMode != 'fe' && anchorMode != 'none'));
		if (nmvAtlasAnchorFix) nmvAtlasKey = json.image;
		else nmvAtlasKey = null;
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

				// NMV 兼容：atlas 角色没有 FlxSprite 意义上的 frame，而 beach.hx 的轮光
				// shader 读 character.frame.uv / frame.angle（每帧）。用 1x1 白图造一个
				// uv 全域(0..1)的合成帧 —— NMV useRenderTexture 语义下 frame 即整张贴图。
				if (this.frame == null)
				{
					var dummyG:FlxGraphic = FlxG.bitmap.create(1, 1, FlxColor.WHITE, false, 'nmv_dummy_frame');
					var dummyF:FlxFrame = new FlxFrame(dummyG);
					dummyF.frame = FlxRect.get(0, 0, 1, 1);
					dummyF.uv = FlxRect.get(0, 0, 1, 1);
					dummyF.angle = FlxFrameAngle.ANGLE_0;
					this.frame = dummyF;
				}
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
		// 血条颜色：NMV 语料 139/162 只写单值 `healthbar_colour`（ARGB int），少数才写 `healthbar_colors` 数组。
		// 只读数组会让绝大多数角色落到灰色 [161,161,161] → 血条/图标/血量文字全变灰（"小图标色彩缺失"）。
		if (json.healthbar_colors != null && json.healthbar_colors.length > 2)
			healthColorArray = json.healthbar_colors;
		else if (json.healthbar_colour != null)
		{
			final hc:FlxColor = FlxColor.fromInt(json.healthbar_colour);
			healthColorArray = [hc.red, hc.green, hc.blue];
		}
		else
			healthColorArray = [161, 161, 161];
		vocalsFile = json.vocals_file != null ? json.vocals_file : '';
		originalFlipX = (json.flip_x == true);
		editorIsPlayer = json._editor_isPlayer;
		flags = (json.flags != null) ? json.flags : {};
		scalableOffsets = (json.scalableOffsets != null) ? json.scalableOffsets : true;
		healthColour = (json.healthbar_colour != null) ? json.healthbar_colour
			: FlxColor.fromRGB(healthColorArray[0], healthColorArray[1], healthColorArray[2]);
		gameoverCharacter = (json.gameover_character != null) ? json.gameover_character : '';
		gameoverLoopDeathSound = json.gameover_loop_sound;
		// 另外两个死亡音效此前没读 → 只有 loop 生效、首音效/确认音永远是默认的 fnf_loss_sfx /
		// gameOverEnd。语料 13 个角色带 initial（bf-fall 的 stage/ejected_death、
		// bf-stick 的 stage/stickbf_Death…），读法照抄 NMV Character.hx:200-202。
		gameoverInitialDeathSound = json.gameover_intial_sound;
		gameoverConfirmDeathSound = json.gameover_confirm_sound;
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
					var hasFrameLabel:Bool = false;
					try hasFrameLabel = atlas.anim.getFrameLabel(animName) != null catch(e:Dynamic) {}
					var exactSymbol:Bool = atlas.anim.symbolDictionary != null && atlas.anim.symbolDictionary.exists(animName);

					// 注册优先级（**逐字对齐** NMV `FunkinSprite.addAnimByIndices / addAnimByPrefix`）：
					//   `findFrameLabelIndices(prefix)` 非空 → 标签；否则有同名符号 → 符号；否则前缀。
					// ① 有 json indices 且 name 是根 timeline 的帧标签 → **帧标签段 + indices**
					//    （`addByFrameLabelIndices` 语义：indices 是标签段内的相对序号）。
					//    这一条是 bf-fall（ejected）"有的唱姿偏有的不偏"的正解：它的
					//    `sing*-loop` / `idle-loop` / `hey-loop` 的 name（`animations/right`…）同时是
					//    主符号 `__BTA_TEMP_SPRITEMAP_PACKED_SYMBOL` 的帧标签，NMV 走的是主符号时间线；
					//    移植端此前 indices 优先 → 掉进子符号，**内容与锚点都换了一条时间线**
					//    （主符号的实例矩阵带 (-211.6,-241.05) 的打包位移，只改锚点会把画面推得更远）。
					// ② 有 indices 但没有同名标签 → 符号 indices（子符号）。
					// ③ 无 indices 但有同名标签 → 帧标签（根时间线）。
					//    white/whitedk 的 json name（'idle'/'right'/'idle_w'…）与根时间线的帧标签
					//    完全同名，NMV 走的是标签（所有姿势共用根时间线的包围盒 → 位置稳定）；
					//    走姿势符号则每个姿势各算一个包围盒 → 逐姿势位移（"到处飘"）。
					//    旧代码担心的"同名包装覆盖真符号导致递归闪退"不成立：safe 包装的字典键是
					//    `@<符号>@<动画>`，不写既有键。
					// ④ 精确符号（前缀歧义时用全帧 indices 的 safe 包装，不覆盖字典）。
					// ⑤ 帧标签兜底。
					// ⑥ 前缀兜底。
					// 每步失败就往下掉（json 的 name 带不带目录名跟字典键不一定一致：
					// yellow 写 'yellow idle'、键是 'animations/yellow idle'；Nene 写 'Idle'）。
					var registered:Bool = false;
					if(animIndices != null && animIndices.length > 0)
					{
						registered = addFromFrameLabelIndices(animAnim, animName, animIndices, animFps, animLoop);
						if (registered) backend.Bread.crumb('char[' + curCharacter + '] anim ' + animAnim + ' label-idx n=' + animIndices.length);
					}
					if(!registered && animIndices != null && animIndices.length > 0)
					{
						registered = atlas.safeAddBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
						if (registered) backend.Bread.crumb('char[' + curCharacter + '] anim ' + animAnim + ' indices n=' + animIndices.length);
					}
					if(!registered && hasFrameLabel && (animIndices == null || animIndices.length == 0))
					{
						registered = addFromFrameLabel(animAnim, animName, animFps, animLoop);
						if (registered) backend.Bread.crumb('char[' + curCharacter + '] anim ' + animAnim + ' label[' + animName + ']');
					}
					if(!registered && exactSymbol)
					{
						if (prefixAmbiguous(animName))
						{
							// 'black left' vs 'black left alt'：fork 的 addBySymbol 抓哪个看 Map
							// 顺序，改用显式全帧 indices 的 safe 包装（不覆盖字典）。
							var sym = atlas.anim.symbolDictionary.get(animName);
							var frameCount:Int = (sym != null && sym.timeline != null) ? sym.timeline.totalFrames : 0;
							var all:Array<Int> = [for (i in 0...frameCount) i];
							registered = atlas.safeAddBySymbolIndices(animAnim, animName, all, animFps, animLoop);
							if (registered) backend.Bread.crumb('char[' + curCharacter + '] anim ' + animAnim + ' exact-ambiguous n=' + frameCount);
						}
						else
						{
							atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
							registered = atlas.anim.existsByName(animAnim);
							if (registered) backend.Bread.crumb('char[' + curCharacter + '] anim ' + animAnim + ' exact');
						}
					}
					if(!registered && hasFrameLabel)
					{
						registered = addFromFrameLabel(animAnim, animName, animFps, animLoop);
						if (registered) backend.Bread.crumb('char[' + curCharacter + '] anim ' + animAnim + ' label[' + animName + ']');
					}
					if(!registered)
					{
						atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
						registered = atlas.anim.existsByName(animAnim);
						if (registered) backend.Bread.crumb('char[' + curCharacter + '] anim ' + animAnim + ' prefix');
					}
					if(!registered)
						backend.Bread.crumb('char[' + curCharacter + '] anim ' + animAnim + ' FAILED name=' + animName);
					else
					{
						// 实际绑定的符号（查"组件混用/播放串台"用：动画名 → 符号名）
						var played = atlas.anim.getByName(animAnim);
						if (played != null && played.instance != null && played.instance.symbol != null)
							backend.Bread.crumb('char[' + curCharacter + '] bind ' + animAnim + ' -> ' + played.instance.symbol.name);
					}
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

	/** 上次播放的动画名。**必须给空串初始化**：hxcpp 上 String 字段默认是 null，
	 *  `getAnimationName()` 被脚本/Voider 面广泛调用（getSingDisplacement、bf-running），
	 *  任何一次 `null.substr()` 都是裸 NPE。 */
	var _lastPlayedAnimation:String = '';
	inline public function getAnimationName():String
	{
		return _lastPlayedAnimation == null ? '' : _lastPlayedAnimation;
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

	/**
	 * NMV flixel fork 的离屏缓存脏标记。FE 没有这条渲染路径，但字段必须存在：
	 * doubletrouble.hx:378 `red.animation.onFrameChange.add(function(_, _, _) dad._renderTextureDirty = true)`
	 * 是在**每帧回调里**写它，缺字段会被 HScript 的 `Reflect.setProperty` 抛
	 * `Invalid field:_renderTextureDirty`，变成逐帧刷屏。
	 */
	public var _renderTextureDirty:Bool = false;

	/** NMV 角色脚本直接调 char.onBeatHit(curBeat)；3 主角的跳舞走 PlayState beatHit →
	 *  dance()（此处被脚本直调时按 NMV Bopper 语义驱动节拍舞），脚本自建的角色
	 *  （redmungus/maroon/grey/yellow 等）没有任何别的跳舞驱动，空桩会让它们全程站桩
	 *  （2026-10-31 用户复核：voting redmungus 没动作）。 */
	public function onBeatHit(curBeat:Int):Void
	{
		if (!debugMode && !skipDance && !specialAnim && danceEveryNumBeats != 0 && curBeat % danceEveryNumBeats == 0)
			dance();
	}

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

		// NMV `Character.playAnim` 会先 `animToPlay += animSuffix` 再播。
		// danger（black）的整段"变身"就靠这个：舞台脚本 `case 'scream danger'` 里设
		// `dad.animSuffix = '-mad'`，此后所有 `playAnim('idle')` 自动变成 `idle-mad`
		// （json 里那 5 条 `black * mad` 动画）。移植端此前**没有 animSuffix 字段**，
		// 脚本写它只会被静默丢掉 → 变身不生效（用户报的"Danger Black 中间变身失败"）。
		// NMV 是直接拼、拼不到就拉倒；这里拼完先查一次，缺变体就退回原名，
		// 避免某个动画没有 mad 版时整条动画空掉。
		var target:String = AnimName;
		if (animSuffix != null && animSuffix.length > 0 && hasAnimation(AnimName + animSuffix)) target = AnimName + animSuffix;

		if(!isAnimateAtlas)
		{
			animation.play(target, Force, Reversed, Frame);
		}
		else
		{
			atlas.anim.play(target, Force, Reversed, Frame);
			atlas.update(0);
			animFlipX = (animFlipXMap.get(target) == true);
		}
		_lastPlayedAnimation = target;

		if (hasAnimation(target))
		{
			#if flxanimate
			if (nmvAtlasAnchorFix)
			{
				// 逐动画锚点（确定性包围盒）：json 偏移(翻转修正) + 该动画自己的包围盒锚
				nmvApplyOffset(target);
			}
			else
			{
				var daOffset = animOffsets.get(target);
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
					offset.set(daOffset[0], daOffset[1]);
			}
			#else
			var daOffset = animOffsets.get(target);
			offset.set(daOffset[0], daOffset[1]);
			#end
		}
		//else offset.set(0, 0);

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

	#if flxanimate
	/** fork 的 addBySymbol 是前缀匹配：除精确同名外还有别的符号以该名为前缀时返回 true。 */
	/**
	 * 用根时间线的帧标签段注册动画（NMV `addByFrameLabel` 语义）。
	 * safe 包装：字典键 `@<根符号>@<动画>`，不覆盖任何既有符号。
	 */
	function addFromFrameLabel(animAnim:String, animName:String, animFps:Int, animLoop:Bool):Bool
	{
		var labelFrame = null;
		try labelFrame = atlas.anim.getFrameLabel(animName) catch(e:Dynamic) {}
		if (labelFrame == null) return false;

		var labelIndices:Array<Int> = labelFrame.getFrameIndices();
		if (labelIndices.length <= 0) return false;

		var rootName:String = atlas.anim.stageInstance.symbol.name;
		return atlas.safeAddBySymbolIndices(animAnim, rootName, labelIndices, animFps, animLoop);
	}

	/**
	 * NMV `addByFrameLabelIndices` 语义：帧标签段 + json indices。
	 * `indices` 是**标签段内的相对序号**（不是符号绝对帧号），越界的直接丢弃 ——
	 * 参考引擎 `FlxAnimateController.addByFrameLabelIndices` 就是
	 * `for (index in indices) { frameIndex = foundFrames[index]; if (frameIndex != null) useable.push(frameIndex); }`
	 * 的反向裁剪，越界只是少一帧（gf 的 danceLeft 写了个 30、段长正好 30）。
	 *
	 * 关键是 timeline：包装符号引用的是**主符号**，所以内容（含主符号上那条实例矩阵的
	 * 打包位移）与 `NmvAtlasAnchor` 取的包围盒都是主符号那一条，与 NMV 完全同源。
	 */
	function addFromFrameLabelIndices(animAnim:String, animName:String, indices:Array<Int>, animFps:Int, animLoop:Bool):Bool
	{
		var labelFrame = null;
		try labelFrame = atlas.anim.getFrameLabel(animName) catch(e:Dynamic) {}
		if (labelFrame == null) return false;

		var found:Array<Int> = labelFrame.getFrameIndices();
		if (found.length <= 0) return false;

		var useable:Array<Int> = [];
		for (i in indices)
			if (i >= 0 && i < found.length) useable.push(found[i]);
		if (useable.length <= 0) return false;

		var rootName:String = atlas.anim.stageInstance.symbol.name;
		return atlas.safeAddBySymbolIndices(animAnim, rootName, useable, animFps, animLoop);
	}

	function prefixAmbiguous(symbolName:String):Bool
	{
		var count:Int = 0;
		for (key in atlas.anim.symbolDictionary.keys())
		{
			if (key != null && key.length >= symbolName.length && key.substr(0, symbolName.length) == symbolName)
			{
				count++;
				if (count > 1) return true;
			}
		}
		return false;
	}
	#end

	/**
	 * NMV：当前帧的读写口（bf-running 用 legs.animCurFrame 对齐两套动画的帧）。
	 * 语义与 NMV FunkinSprite 一致：无动画时读 0、写丢弃。
	 * atlas 角色走 atlas.anim（NMV 的统一控制器等价物）——旧实现只读标准控制器，
	 * atlas 角色恒 0/写丢弃，bf-running 的帧同步链静默失效。
	 */
	public var animCurFrame(get, set):Int;

	inline function get_animCurFrame():Int
	{
		#if flxanimate
		if (isAnimateAtlas)
			return (atlas == null || atlas.anim == null || atlas.anim.curInstance == null) ? 0 : atlas.anim.curFrame;
		#end
		return (animation == null || animation.curAnim == null) ? 0 : animation.curAnim.curFrame;
	}

	inline function set_animCurFrame(value:Int):Int
	{
		#if flxanimate
		if (isAnimateAtlas)
		{
			if (atlas != null && atlas.anim != null) atlas.anim.curFrame = value;
			return value;
		}
		#end
		if (animation != null && animation.curAnim != null) animation.curAnim.curFrame = value;
		return value;
	}

	/**
	 * NMV 面（FunkinSprite.isAnimFinished 同构语义，nenelobby.hx 在用）：
	 * 无动画 = false；atlas 角色走 atlas.anim.finished，Sparrow 走标准面。
	 */
	public function isAnimFinished():Bool
	{
		#if flxanimate
		if (isAnimateAtlas)
			return atlas != null && atlas.anim != null && atlas.anim.curInstance != null && atlas.anim.finished;
		#end
		return animation != null && animation.curAnim != null && animation.curAnim.finished;
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
	 * NMV `Character.animSuffix`：`playAnim` 时自动追加到动画名后面。
	 *
	 * 用途是"整段变身"——danger（black）的舞台脚本在 `scream danger` 事件里设
	 * `dad.animSuffix = '-mad'`，之后所有 `playAnim('idle')` 都变成 `idle-mad`，
	 * 直到 `unscream danger` 清掉。NMV 原版是 `animToPlay += animSuffix` 直接拼。
	 * 移植端此前没有这个字段，脚本写入被静默丢弃 → 变身不生效。
	 */
	public var animSuffix:String = '';
	/** 本次加载的角色 json 是否来自 NMV 语料（content/NMVMODS）；changeCharacter 里按解析路径判定。 */
	var nmvContentChar:Bool = false;
	/** 锚点缓存键：角色 json 的 image 路径（确定性结果跨实例复用）。 */
	var nmvAtlasKey:String;
	/** 已打过 `nmv off` 面包屑的动画（每个动画一次，验证基准用）。 */
	var nmvLoggedOffsets:Array<String> = [];

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
	 * offset = json 偏移 + 当前动画的包围盒锚（nmvAtlasAnchorFix 专用，playAnim 专用）。
	 *
	 * 推导（两边都是 openfl Matrix.translate = 裸加，锚落在屏幕空间、与 scale 无关）：
	 *   NMV  : x = ±scale·p + (-bx [+ bw 当翻转]) + 屏幕位置 - json偏移
	 *   本端 : x = ±scale·p + 屏幕位置 - offset
	 *   ⇒ offset = json偏移 + bx [- bw 当翻转]
	 * 翻转项来自 MaybeMaru 的 `scale(-1,1); translate(bounds.width,0)`（Dot-Stuff 只翻不补宽）。
	 * json 偏移不随翻转镜像 —— NMV 的 correctFlippedOffsets 对角色恒为 false。
	 */
	function nmvApplyOffset(animName:String):Void
	{
		var daOffset = animOffsets.get(animName);
		if (daOffset == null) daOffset = [0, 0];

		final rect:Null<FlxRect> = nmv.utils.NmvAtlasAnchor.getBounds(atlas, nmvAtlasKey, animName);
		if (rect == null)
		{
			offset.set(daOffset[0], daOffset[1]);
			return;
		}

		final flipXr:Bool = (flipX != animFlipX);

		// **不乘 scale** —— 2026-11-01 用 openfl 源码证伪了"符号空间"的说法：
		//   openfl 9.5.2 `Matrix.translate` 是 `tx += dx; ty += dy;`（**纯加**，不乘 a/d），
		//   只有 `Matrix.scale` 才是右乘（`a *= sx; b *= sy`）。
		// 所以参考引擎 `drawAnimate` 里那句 `matrix.translate(-bounds.x, -bounds.y)`
		// 落在**世界空间**，与角色 scale 无关（62 号注释原本是对的，我 10-31 深夜按
		// "translate 是右乘"改错了，这里回退）。翻转项同理：`scale(-1,1)` 只翻 a，
		// `translate(bounds.width, 0)` 仍是世界空间纯加 → `bx - bw`。
		final ax:Float = rect.x - (flipXr ? rect.width : 0);
		final ay:Float = rect.y - (flipY ? rect.height : 0);
		offset.set(daOffset[0] + ax, daOffset[1] + ay);

		if (!nmvLoggedOffsets.contains(animName))
		{
			nmvLoggedOffsets.push(animName);
			// 诊断行：maroonthreat（scale 0.9）的逐动画漂移靠这一行定位。
			// `origin` 是 drawLimb 的缩放中心（`(p-o)*s+o`），origin 不为 0 时
			// scale≠1 的角色会整体偏 `o*(1-s)`；`fw/fh` 是 flxanimate 的绘制尺寸，
			// 用来判断 bounds 与真实内容是否错位。
			backend.Bread.crumb('nmv off ' + curCharacter + ' ' + animName + ' flip=' + flipXr + ' scale=' + scale.x + ',' + scale.y + ' bw=' + Std.int(rect.width) + ' bh='
				+ Std.int(rect.height) + ' json=' + Std.int(daOffset[0]) + ',' + Std.int(daOffset[1]) + ' anchor=' + Std.int(ax) + ',' + Std.int(ay) + ' -> '
				+ Std.int(offset.x) + ',' + Std.int(offset.y) + ' origin=' + Std.int(origin.x) + ',' + Std.int(origin.y) + ' fw=' + Std.int(frameWidth) + ','
				+ Std.int(frameHeight));
		}
	}

	public override function destroy()
	{
		atlas = FlxDestroyUtil.destroy(atlas);
		super.destroy();
	}
	#end
}
