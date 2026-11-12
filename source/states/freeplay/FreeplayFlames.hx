package states.freeplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxTimer;
import backend.Paths;

/**
 * Freeplay 星星上方的火焰（移植自官方 FunkIn 的 FreeplayFlames）。
 * difficulty > 10 时由 DifficultyStars.flameCheck() 点亮 difficulty - 10 个，
 * 15 星全开 5 个；点燃按 0.25s 间隔错峰，快速切难度不会残留旧火焰。
 *
 * 摆位沿用官方相对星星组的几何：底座 (-37, -118)，向右上斜排 (29, 6)。
 * 成员坐标是相对量，setFlamePositions 以本组当前位置为锚（本组由宿主群组带着走）。
 */
class FreeplayFlames extends FlxSpriteGroup
{
	public var flameX(default, set):Float = -37;
	public var flameY(default, set):Float = -118;
	public var flameSpreadX(default, set):Float = 29;
	public var flameSpreadY(default, set):Float = 6;

	public var flameCount(default, set):Int = 0;

	var flameTimer:Float = 0.25;

	var timers:Array<FlxTimer> = [];

	public function new()
	{
		super(0, 0);
		scrollFactor.set();

		for (i in 0...5)
		{
			var flame:FlxSprite = new FlxSprite();
			flame.frames = Paths.getSparrowAtlas('freeplay/freeplayFlame');
			flame.animation.addByPrefix('flame', 'fire loop full instance 1', FlxG.random.int(23, 25), false);
			flame.animation.play('flame');
			flame.visible = false;
			flame.scrollFactor.set();

			// 播完从帧 2 重播，跳过点燃帧实现循环
			flame.animation.onFinish.add(function(_:String)
			{
				flame.animation.play('flame', true, false, 2);
			});
			add(flame);
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		// 每帧按相对量重摆 —— 嵌套群组的坐标传播在不同时机/分辨率下不可靠，
		// 与其赌 add 链的偏移，不如直接以本组当前位置为锚断言（5 个精灵，代价可忽略）
		setFlamePositions();
	}

	function set_flameCount(value:Int):Int
	{
		// 先杀掉所有未完成的错峰计时器 —— 否则快速切难度时旧火焰会突然冒出来
		for (timer in timers)
		{
			timer.active = false;
			timer.destroy();
			timers.remove(timer);
		}

		this.flameCount = value;

		var visibleCount:Int = 0;
		for (i in 0...5)
		{
			var flame:FlxSprite = members[i];
			if (flame == null) continue;

			if (i < flameCount)
			{
				if (!flame.visible)
				{
					// 逐个错峰点燃：第 n 个延迟 flameTimer * n
					var nextTimer:FlxTimer = new FlxTimer().start(flameTimer * visibleCount, function(currentTimer:FlxTimer)
					{
						if (i >= this.flameCount) return; // 计时期间难度又切走了
						timers.remove(currentTimer);
						flame.animation.play('flame', true);
						flame.visible = true;
					});
					timers.push(nextTimer);

					visibleCount++;
				}
			}
			else
			{
				flame.visible = false;
			}
		}
		return this.flameCount;
	}

	function setFlamePositions():Void
	{
		for (i in 0...5)
		{
			var flame:FlxSprite = members[i];
			if (flame == null) continue;
			flame.x = x + flameX + (flameSpreadX * i);
			flame.y = y + flameY + (flameSpreadY * i);
		}
	}

	function set_flameX(value:Float):Float
	{
		this.flameX = value;
		setFlamePositions();
		return this.flameX;
	}

	function set_flameY(value:Float):Float
	{
		this.flameY = value;
		setFlamePositions();
		return this.flameY;
	}

	function set_flameSpreadX(value:Float):Float
	{
		this.flameSpreadX = value;
		setFlamePositions();
		return this.flameSpreadX;
	}

	function set_flameSpreadY(value:Float):Float
	{
		this.flameSpreadY = value;
		setFlamePositions();
		return this.flameSpreadY;
	}
}
