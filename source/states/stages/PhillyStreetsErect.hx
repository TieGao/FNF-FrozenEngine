package states.stages;

#if BASE_GAME_ERECT
/**
 * Weekend 1（phillyStreets）的 erect 变体舞台。
 *
 * 继承 `PhillyStreets`：车流 / 红绿灯 / 雨 shader / Nene 的刀 / 谱面 note type / darnell 过场全都复用，
 * 只换掉道具那一摊（`createStageProps()`）并补上 erect 独有的滚动天空、雾带和纸片。
 *
 * 道具 / 坐标照原版 `phillyStreetsErect` 舞台（引擎侧 erect 图片与原版逐字节相同，坐标能直接用）；
 * 原版没有的雾带与「三张平铺天空」照 Erect Mode 的 `streetsErect.lua`。
 */
class PhillyStreetsErect extends PhillyStreets
{
	/** 雾带配置：6 组 × 3 张，同组互相追尾、出屏后绕回队尾。 */
	static var MIST_IMAGE:Array<String> = ['mistMid', 'mistMid', 'mistBack', 'mistMid', 'mistBack', 'mistMid'];
	static var MIST_SCROLL:Array<Float> = [1.2, 1.1, 1.2, 0.95, 0.8, 0.5];
	static var MIST_ALPHA:Array<Float> = [0.6, 0.6, 0.8, 0.5, 1, 1];
	static var MIST_VELOCITY:Array<Float> = [172, 150, -80, -50, 40, 20];
	static var MIST_SCALE:Array<Float> = [1, 1, 1, 0.8, 0.7, 1.1];
	static var MIST_BASE_Y:Array<Float> = [660, 500, 540, 230, 170, -80];
	static var MIST_SWAY:Array<Float> = [70, 80, 60, 70, 50, 100];
	static var MIST_SWAY_SPEED:Array<Float> = [0.35, 0.3, 0.4, 0.3, 0.35, 0.08];

	var skyTiles:Array<BGSprite> = [];
	var mists:Array<Array<BGSprite>> = [null, null, null, null, null, null];
	var paper:FlxSprite;
	var paperCoolingDown:Bool = false;
	var mistTime:Float = 0;

	override function createStageProps():Void
	{
		// 原版 erect 的天空是 3 张 phillySkybox 平铺滚动（lowQuality 时 2 张）
		var low:Bool = ClientPrefs.data.lowQuality;
		var skyCount:Int = low ? 2 : 3;
		var skyStartX:Float = low ? -450 : -650;
		for (i in 0...skyCount)
		{
			var sky:BGSprite = new BGSprite('phillyStreets/erect/phillySkybox', skyStartX, -375, 0.1, 0.1);
			sky.setGraphicSize(Std.int(sky.width * 0.65));
			sky.updateHitbox();
			sky.x += sky.width * i;
			add(sky);
			skyTiles.push(sky);
		}

		var skyline:BGSprite = new BGSprite('phillyStreets/erect/phillySkyline', -545, -273, 0.2, 0.2);
		add(skyline);
		darkenable.push(skyline);

		var city:BGSprite = new BGSprite('phillyStreets/erect/phillyForegroundCity', 600, 69, 0.3, 0.3);
		add(city);
		darkenable.push(city);

		addMist(5, city); // mist6 贴在城市后面

		var city2:BGSprite = new BGSprite('phillyStreets/erect/phillyForegroundCity', 1860, 185, 0.3, 0.3);
		city2.angle = 5;
		city2.flipX = true;
		add(city2);
		darkenable.push(city2);

		var construction:BGSprite = new BGSprite('phillyStreets/erect/phillyConstruction', 1795, 360, 0.7, 1);
		add(construction);
		darkenable.push(construction);

		var highwayLights:BGSprite = new BGSprite('phillyStreets/erect/phillyHighwayLights', 122, 201, 0.8, 0.8);
		add(highwayLights);
		darkenable.push(highwayLights);

		// 这张 lightmap 原版就用非 erect 的那份
		var highwayLightsLightmap:BGSprite = new BGSprite('phillyStreets/phillyHighwayLights_lightmap', 122, 201, 0.8, 0.8);
		highwayLightsLightmap.blend = ADD;
		highwayLightsLightmap.alpha = 0.6;
		add(highwayLightsLightmap);
		darkenable.push(highwayLightsLightmap);

		var highway:BGSprite = new BGSprite('phillyStreets/erect/phillyHighway', -23, 105, 0.8, 0.8);
		add(highway);
		darkenable.push(highway);

		// 原版 zIndex：cars2(78) 在 cars1(80) 后面，且 cars2 水平翻转
		phillyCars2 = new BGSprite('phillyStreets/erect/phillyCars', 1200, 818, 0.9, 1, ['car1', 'car2', 'car3', 'car4'], false);
		phillyCars2.flipX = true;
		add(phillyCars2);
		darkenable.push(phillyCars2);

		phillyCars = new BGSprite('phillyStreets/erect/phillyCars', 1200, 818, 0.9, 1, ['car1', 'car2', 'car3', 'car4'], false);
		add(phillyCars);
		darkenable.push(phillyCars);

		addMist(4, phillyCars); // mist5 贴在车后面

		phillyTraffic = new BGSprite('phillyStreets/erect/phillyTraffic', 1840, 608, 0.9, 1, ['redtogreen', 'greentored'], false);
		add(phillyTraffic);
		darkenable.push(phillyTraffic);

		var trafficLightmap:BGSprite = new BGSprite('phillyStreets/erect/phillyTraffic_lightmap', 1840, 608, 0.9, 1);
		trafficLightmap.blend = ADD;
		trafficLightmap.alpha = 0.6;
		add(trafficLightmap);
		darkenable.push(trafficLightmap);

		var grey1:BGSprite = new BGSprite('phillyStreets/erect/greyGradient', -388, 7, 1, 1);
		grey1.setGraphicSize(Std.int(grey1.width * 1.3));
		grey1.updateHitbox();
		grey1.blend = ADD;
		grey1.alpha = 0.3;
		add(grey1);
		darkenable.push(grey1);

		addMist(3, grey1); // mist4 贴在渐变后面

		var grey2:BGSprite = new BGSprite('phillyStreets/erect/greyGradient', -388, 7, 1, 1);
		grey2.setGraphicSize(Std.int(grey2.width * 1.3));
		grey2.updateHitbox();
		grey2.blend = MULTIPLY;
		grey2.alpha = 0.8;
		add(grey2);
		darkenable.push(grey2);

		var foreground:BGSprite = new BGSprite('phillyStreets/erect/phillyForeground', 88, 317, 1, 1);
		add(foreground);
		darkenable.push(foreground);

		// 最前面三组雾带（原版是 addLuaSprite(name, true)）
		addMist(0);
		addMist(1);
		addMist(2);

		paper = new FlxSprite(350, 608);
		paper.frames = Paths.getSparrowAtlas('phillyStreets/erect/paper');
		paper.animation.addByPrefix('blow', 'Paper Blowing instance 1', 24, false);
		paper.scrollFactor.set(1.1, 1.1);
		paper.antialiasing = ClientPrefs.data.antialiasing;
		paper.visible = false;
		add(paper);
	}

	/** 建一组雾带（3 张同图互相追尾）。给了 `after` 就插在它后面，否则追加到最前。 */
	function addMist(index:Int, ?after:FlxSprite):Void
	{
		if (ClientPrefs.data.lowQuality) return;

		var group:Array<BGSprite> = [];
		for (i in 0...3)
		{
			var mist:BGSprite = new BGSprite('phillyStreets/erect/${MIST_IMAGE[index]}', -650, -100, MIST_SCROLL[index], MIST_SCROLL[index]);
			mist.setGraphicSize(Std.int(mist.width * MIST_SCALE[index]));
			mist.updateHitbox();
			mist.blend = ADD;
			mist.alpha = MIST_ALPHA[index];
			mist.color = 0x5C5C5C;
			mist.active = true; // BGSprite 传 null animArray 时会关掉 active，velocity 就不生效了
			mist.velocity.x = MIST_VELOCITY[index];
			mist.x += mist.width * i;

			if (after != null) insert(members.indexOf(after) + 1, mist);
			else add(mist);
			group.push(mist);
		}
		mists[index] = group;
	}

	override function update(elapsed:Float)
	{
		mistTime += elapsed;

		for (sky in skyTiles)
		{
			if (sky.x < -sky.width * 2) sky.x += sky.width * 3;
			sky.x -= elapsed * 22;
		}

		for (i in 0...mists.length)
		{
			var group:Array<BGSprite> = mists[i];
			if (group == null) continue;

			for (mist in group)
			{
				if (mist.velocity.x > 0)
				{
					if (mist.x > mist.width * 1.5) mist.x -= mist.width * 3;
				}
				else if (mist.x < -mist.width * 1.5) mist.x += mist.width * 3;

				mist.y = MIST_BASE_Y[i] + Math.sin(mistTime * MIST_SWAY_SPEED[i]) * MIST_SWAY[i];
			}
		}

		super.update(elapsed);
	}

	override function beatHit()
	{
		super.beatHit(); // 车流 / 红绿灯

		if (paper == null || paperCoolingDown) return;
		if (!FlxG.random.bool(0.6)) return;

		paperCoolingDown = true;
		paper.y = 608 + FlxG.random.float(-150, 150);
		paper.visible = true;
		paper.animation.play('blow', true);
		new FlxTimer().start(2, function(_)
		{
			paper.visible = false;
			paperCoolingDown = false;
		});
	}
}
#end
