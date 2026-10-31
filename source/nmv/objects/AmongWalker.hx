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
		y = (savedHeight - height);

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
		actionTimer -= elapsed;

		if (actionTimer <= 0) triggerNextAction();

		super.update(elapsed);

		if (!hibernating)
		{
			if (x > xRange[1] && right)
			{
				actionTimer = FlxG.random.float(5, 10);
				visible = false;

				x -= 50;
				swapSkin();
				right = false;
				hibernating = true;

				onAway.dispatch();
			}
			else if (x < xRange[0] && !right)
			{
				actionTimer = FlxG.random.float(5, 10);
				visible = false;

				x += 50;
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
