package nmv.objects;

import flixel.util.FlxSignal;
import flixel.FlxG;

/**
 * NMV funkin.objects.stageobjects.AmongWalker 移植。
 *
 * NMV 原版继承 Bopper（未随路线 C 移植），这里改继承 FunkinSprite 并补齐
 * 用到的 Bopper 表面：addAnimByPrefix 的 name→prefix 映射（flxanimate 按
 * 动画名播放，用映射表在 playAnim 时换算）、hasAnim/stopAnim、animCurFrame、
 * canDance。hibernating/idle/right 在 NMV 是私有 var，语料脚本直接赋值
 * （hscript 不受访问控制约束），这里显式 public。
 */
typedef AmongWalkerColorData = {
	var name:String;
	var weight:Float;
	var ?atlas:String;
}

class AmongWalker extends FunkinSprite
{
	public var isCustom:Bool = false;

	public var currentColorData:AmongWalkerColorData = fallbackColor;
	public var currentColor:String = '';
	public var walkSpeed:Float = 30;

	public var xRange:Array<Float> = [0, 0];
	public var savedHeight:Float;

	public var idle:Bool = false;
	public var actionTimer:Float;
	public var right:Bool;
	public var hibernating:Bool = false;

	/** 脚底对齐（y = savedHeight - height）是否已落到真实高度上，见 reloadAtlas。 */
	var yAligned:Bool = false;

	/**
	 * 脚底对齐的固定微调（负 = 更靠上）。
	 *
	 * NMV 原版的高度来自 sparrow 帧高；移植端 flxanimate 的 `height` 是当前帧的
	 * `_flashRect.height`，比 Bopper 的 frameHeight 略小（少掉帧外空白），脚底会偏低。
	 * 用户实测"位置还要再往上移一些"，这里给一个集中可调的常量，不要散落到脚本里。
	 */
	public static var FOOT_BIAS:Float = -140;

	/**
	 * 休眠结束后往屏幕外推的距离。
	 *
	 * 原版是 `x -= 50` 再隐藏：`xRange` 是 `[-700, 1700]` 而屏幕宽 1280，
	 * 但 toogus 的相机在 `camSpecialThing` 里会左右平移，1700 经常落进视野 →
	 * 重新 `visible = true` 时看起来是"屏幕中间凭空冒人"。推远到 250 像素之外。
	 */
	public static var HIDE_PUSH:Float = 400;

	public var canDance:Bool = false;

	public var onAction:FlxTypedSignal<Bool->Bool->Void> = new FlxTypedSignal();
	public var onEnter:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var onAway:FlxTypedSignal<Void->Void> = new FlxTypedSignal();

	public var friends:Array<AmongWalker> = [];

	public var colors:Array<AmongWalkerColorData>;
	public static var defaultColors:Array<AmongWalkerColorData> = [
		{name: 'blue', weight: 1},
		{name: 'brown', weight: 1},
		{name: 'lime', weight: 1},
		{name: 'tan', weight: 1},
		{name: 'white', weight: .85},
		{name: 'yellow', weight: .75},
		{name: 'foe', weight: .05} // its a real color ! source: Pantone
	];
	public static final fallbackColor:AmongWalkerColorData = {name: 'blue', weight: 1};

	public function new(range:Array<Float>, height:Float, thescale:Float, ?friends:Array<AmongWalker>, ?colors:Array<AmongWalkerColorData>)
	{
		super();

		this.colors = (colors ?? defaultColors);

		if (friends != null) this.friends = friends;

		xRange = range;
		savedHeight = height;
		scale.set(thescale, thescale);

		swapSkin();
		triggerNextAction();
	}

	public function findFreeColor():AmongWalkerColorData
	{
		var friendsColors:Array<String> = [for (friend in friends) friend.currentColor];
		var choosableColors:Array<AmongWalkerColorData> = [for (color in colors) if (!friendsColors.contains(color.name)) color];

		if (choosableColors.length == 0)
		{
			trace('we outta color\'s $friendsColors');
			return (Lambda.find(colors, function(color) return (currentColor == color.name)) ?? fallbackColor);
		}

		return FlxG.random.getObject(choosableColors, [for (color in choosableColors) color.weight]);
	}

	public function setCustom(?name:String, ?atlas:String):Void
	{
		if (name == null)
		{
			isCustom = false;
			return swapSkin();
		}

		isCustom = true;

		currentColorData = {
			atlas: atlas,
			name: name,
			weight: 1
		};
		currentColor = currentColorData.name;

		reloadAtlas();
	}

	function swapSkin():Void
	{
		if (!isCustom)
		{
			currentColor = (currentColorData = findFreeColor()).name;

			reloadAtlas();
		}
	}

	function reloadAtlas():Void
	{
		stopAnim();
		if (hasAnim('idle')) removeAnim('idle');
		if (hasAnim('walk')) removeAnim('walk');

		loadNmvAtlas(currentColorData.atlas ?? 'stages/mira/cafeteria/walkers');

		addAnimByPrefix('walk', '$currentColor walk', 24, true);
		addAnimByPrefix('idle', '$currentColor idle', 24, false);
		playAnim('idle', true);

		canDance = idle;

		updateHitbox();
		// 脚底对齐延后到首帧绘制之后：NMV 原版继承 Bopper（sparrow），`updateHitbox()`
		// 当场就把 height 填成帧高，`y = savedHeight - height` 立即成立；移植端走
		// flxanimate，`height` 要等第一次 draw 里 `_flashRect.height` 才算出来，
		// 构造期读到的是 0 → y = savedHeight（整只往下掉一个身高，用户报的"偏下"）。
		yAligned = false;
		playAnim(idle ? 'idle' : 'walk', true);
	}

	// ---- Bopper 表面 ----
	// NMV 的 Bopper 是"标准 animation 控制器"语义：addAnimByPrefix(name, prefix) 按 prefix
	// 解析帧、注册成名为 name 的动画，playAnim(name) 播它。FunkinSprite 的同名方法就是这样
	// （走 flxanimate 侧的 addByFrameLabel/addBySymbol，同时注册标准控制器），所以这里
	// 不再覆写 —— 曾经覆写成"只记 name→prefix 映射"的表，导致 anim 里根本没注册动画，
	// playAnim 全部早退，walkers 只有位移、没有走路动画。

	public function stopAnim():Void
	{
		anim.stop();
	}

	// ---- Bopper 节拍面（NMV Bopper 原样移植；chef.hx 的 walker.onBeatHit(curBeat)
	// 手动驱动——walkers 不进引擎的 beat 派发，舞台脚本自己节拍时调）----

	public var danceEveryNumBeats:Int = 2;
	public var danceSpeed:Int = 1;
	public var idleSuffix:String = '';

	var alternatingDance:Null<Bool> = null;
	var danced:Bool = false;

	public function recalculateDanceIdle():Void
	{
		alternatingDance = hasAnim('danceLeft' + idleSuffix) && hasAnim('danceRight' + idleSuffix);
	}

	public function dance(forced:Bool = false):Void
	{
		if (alternatingDance == null) recalculateDanceIdle();
		if (!canDance) return;

		if (alternatingDance)
		{
			danced = !danced;
			playAnim(danced ? 'danceRight$idleSuffix' : 'danceLeft$idleSuffix', forced);
		}
		else
		{
			playAnim('idle$idleSuffix', forced);
		}
	}

	public function onBeatHit(beat:Int):Void
	{
		if (!isAnimNull() && beat % (danceEveryNumBeats * danceSpeed) == 0) dance();
	}

	// ---- NMV 原版行为 ----

	function setNewActionTime():Void
	{
		actionTimer = FlxG.random.float(.75, 3);
	}

	function triggerNextAction():Void
	{
		if (!hibernating && FlxG.random.bool(20)) right = FlxG.random.bool(50);

		if (!idle && FlxG.random.bool(60))
		{
			idle = true;
		}
		else if (idle && FlxG.random.bool(50))
		{
			idle = false;
		}

		setNewActionTime();

		onAction.dispatch(idle, right);

		if (hibernating)
		{
			hibernating = false;
			visible = true;

			onEnter.dispatch();
		}
	}

	override public function update(elapsed:Float):Void
	{
		// 脚底对齐：等 flxanimate 把真实显示高度算出来（首次 draw 之后）再落一次。
		if (!yAligned && height > 1)
		{
			y = savedHeight - height + FOOT_BIAS;
			yAligned = true;
		}

		actionTimer -= elapsed;

		if (actionTimer <= 0) triggerNextAction();

		super.update(elapsed);

		if (!hibernating)
		{
			if (x > xRange[1] && right)
			{
				actionTimer = FlxG.random.float(5, 10);
				visible = false;

				x = xRange[1] + HIDE_PUSH;
				swapSkin();
				right = false;
				hibernating = true;

				onAway.dispatch();
			}
			else if (x < xRange[0] && !right)
			{
				actionTimer = FlxG.random.float(5, 10);
				visible = false;

				x = xRange[0] - HIDE_PUSH;
				swapSkin();
				right = true;
				hibernating = true;

				onAway.dispatch();
			}

			if (!idle)
			{
				if (canDance)
				{
					playAnim('walk', true);

					canDance = false;
				}

				walk(elapsed);
				flipX = !right;
			}
			else
			{
				if (!canDance)
				{
					walk(elapsed * .5);

					if (animCurFrame == 0 || animCurFrame == 10)
					{
						playAnim('idle', true);

						canDance = true;
					}
				}

				flipX = !right;
			}
		}
	}

	public inline function walk(elapsed:Float):Void
	{
		x += (elapsed * (right ? walkSpeed : -walkSpeed) * 9);
	}
}
