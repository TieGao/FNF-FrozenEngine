package states.stages;

#if BASE_GAME_ERECT
import flixel.FlxSprite;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import objects.Character;
import shaders.AdjustColorShader;

/**
 * Week 1 的 erect 变体舞台（原版 Erect Mode `stageErect.lua` 的 Haxe 版，参照 FPO 的 `StageErect`）。
 *
 * 道具 / 坐标 / ADD 混合照原版摆；`lights` / `lightAbove` 放在 `createPost()`（角色入组之后才跑，层级在角色之上）。
 * `createPost()` 给 bf / dad / gf 各挂一个 `AdjustColorShader` 压暗偏色（设置里 shader 开关为开时）。
 * 另外接了原版的 `Dadbattle Spotlight` 事件（dad-battle 那首 erect 的聚光灯效果）。
 */
class StageErect extends BaseStage
{
	private var smallLight:BGSprite;
	private var lightAbove:BGSprite;

	// Dadbattle Spotlight 事件用的临时精灵（仅当谱面里有该事件时才创建）
	private var spotlightEvent:Bool = false;
	private var blackenScreen:FlxSprite;
	private var spotlight:BGSprite;
	private var smoke1:BGSprite;
	private var smoke2:BGSprite;

	override function create()
	{
		var back:BGSprite = new BGSprite('erect/backDark', 729, -170, 1, 1);
		add(back);

		var crowd:BGSprite = new BGSprite('erect/crowd', 560, 290, 0.8, 0.8, ['Symbol 2 instance 1'], true);
		if (crowd.animation.curAnim != null) crowd.animation.curAnim.frameRate = 12; // 原版 12fps
		add(crowd);

		if (!ClientPrefs.data.lowQuality)
		{
			smallLight = new BGSprite('erect/brightLightSmall', 967, -103, 1.2, 1.2);
			smallLight.blend = ADD;
			add(smallLight);
		}

		var bg:BGSprite = new BGSprite('erect/bg', -603, -277, 1, 1);
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.updateHitbox();
		add(bg);

		var server:BGSprite = new BGSprite('erect/server', -361, 215, 1, 1);
		add(server);

		if (!ClientPrefs.data.lowQuality)
		{
			var greenLight:BGSprite = new BGSprite('erect/lightgreen', -171, 242, 1, 1);
			greenLight.blend = ADD;
			add(greenLight);

			var redLight:BGSprite = new BGSprite('erect/lightred', -101, 560, 1, 1);
			redLight.blend = ADD;
			add(redLight);

			var orangeLight:BGSprite = new BGSprite('erect/orangeLight', 189, -195, 1, 1);
			orangeLight.blend = ADD;
			add(orangeLight);
		}
	}

	override function createPost()
	{
		// lights / lightAbove 在角色之上（createPost 跑于角色入组之后）
		var lights:BGSprite = new BGSprite('erect/lights', -601, -147, 1.2, 1.2);
		add(lights);

		if (!ClientPrefs.data.lowQuality)
		{
			lightAbove = new BGSprite('erect/lightAbove', 804, -117, 1, 1);
			lightAbove.blend = ADD;
			add(lightAbove);
		}

		// 原版脚本读 shadersEnabled：关掉就保持原色
		if (ClientPrefs.data.shaders)
		{
			var bfShader:AdjustColorShader = new AdjustColorShader();
			bfShader.apply(12, 0, -23, 7);

			var dadShader:AdjustColorShader = new AdjustColorShader();
			dadShader.apply(-32, 0, -33, -23);

			var gfShader:AdjustColorShader = new AdjustColorShader();
			gfShader.apply(-9, 0, -30, -4);

			if (boyfriend != null) boyfriend.shader = bfShader;
			if (dad != null) dad.shader = dadShader;
			if (gf != null) gf.shader = gfShader;
		}

		if (spotlightEvent) buildSpotlightSprites();
	}

	// 谱面里有 Dadbattle Spotlight 事件时，预先建好（隐藏）相关精灵，事件触发再显隐
	override function eventPushed(event:objects.Note.EventNote)
	{
		if (event.event == 'Dadbattle Spotlight') spotlightEvent = true;
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		if (eventName != 'Dadbattle Spotlight' || !spotlightEvent) return;

		var value:Float = (flValue1 != null) ? flValue1 : 0;

		if (value > 0)
		{
			if (value == 1)
			{
				defaultCamZoom += 0.12;
				if (smallLight != null) smallLight.visible = false;
				if (lightAbove != null) lightAbove.visible = false;
				if (blackenScreen != null) blackenScreen.visible = true;
				if (spotlight != null) spotlight.visible = true;
				if (smoke1 != null) smoke1.visible = true;
				if (smoke2 != null) smoke2.visible = true;
			}

			var target:Character = (value > 2) ? boyfriend : dad;
			if (target != null && spotlight != null)
			{
				spotlight.x = target.getMidpoint().x - spotlight.width / 2;
				spotlight.y = target.y + target.height - spotlight.height + 50;
			}
			new FlxTimer().start(0.12, function(_) { if (spotlight != null) spotlight.alpha = 0.375; });

			if (smoke1 != null) FlxTween.tween(smoke1, {alpha: 0.7}, 1.5, {ease: FlxEase.quadInOut});
			if (smoke2 != null) FlxTween.tween(smoke2, {alpha: 0.7}, 1.5, {ease: FlxEase.quadInOut});
		}
		else
		{
			defaultCamZoom -= 0.12;
			if (smallLight != null) smallLight.visible = true;
			if (lightAbove != null) lightAbove.visible = true;
			if (blackenScreen != null) blackenScreen.visible = false;
			if (spotlight != null) spotlight.visible = false;
			if (smoke1 != null) FlxTween.tween(smoke1, {alpha: 0}, 0.7, {ease: FlxEase.linear});
			if (smoke2 != null) FlxTween.tween(smoke2, {alpha: 0}, 0.7, {ease: FlxEase.linear});
		}
	}

	private function buildSpotlightSprites():Void
	{
		blackenScreen = new BGSprite(null, -800, -400, 0, 0);
		blackenScreen.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), 0xFF000000);
		blackenScreen.alpha = 0.25;
		blackenScreen.visible = false;
		add(blackenScreen);

		spotlight = new BGSprite('erect/spotlight', 400, -400, 1, 1);
		spotlight.blend = ADD;
		spotlight.alpha = 0;
		spotlight.visible = false;
		add(spotlight);

		var smoke1OffsetY:Float = FlxG.random.float(-15, 15);
		var smoke1Scale:Float = FlxG.random.float(1.1, 1.22);
		var smoke1Velocity:Float = FlxG.random.float(15, 22);
		smoke1 = new BGSprite('erect/smoke', -1650, 680 + smoke1OffsetY, 1.2, 1.05);
		smoke1.setGraphicSize(Std.int(smoke1.width * smoke1Scale));
		smoke1.updateHitbox();
		smoke1.alpha = 0;
		smoke1.visible = false;
		smoke1.active = true; // 需要让 velocity 生效
		smoke1.velocity.x = smoke1Velocity;
		add(smoke1);

		var smoke2OffsetY:Float = FlxG.random.float(-15, 15);
		var smoke2Scale:Float = FlxG.random.float(1.1, 1.22);
		var smoke2Velocity:Float = FlxG.random.float(-22, -15);
		smoke2 = new BGSprite('erect/smoke', 1850, 680 + smoke2OffsetY, 1.2, 1.05);
		smoke2.setGraphicSize(Std.int(smoke2.width * smoke2Scale));
		smoke2.updateHitbox();
		smoke2.alpha = 0;
		smoke2.visible = false;
		smoke2.active = true;
		smoke2.flipX = true;
		smoke2.velocity.x = smoke2Velocity;
		add(smoke2);
	}
}
#end
