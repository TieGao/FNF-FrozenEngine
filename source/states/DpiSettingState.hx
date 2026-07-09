package states;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.effects.FlxFlicker;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import Main;

class DpiSettingState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var isYes:Bool = true;
	var texts:FlxTypedSpriteGroup<FlxText>;
	var bg:FlxSprite;

	override function create()
	{
		super.create();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		texts = new FlxTypedSpriteGroup<FlxText>();
		texts.alpha = 0.0;
		add(texts);

		var warnText:FlxText = new FlxText(0, 0, FlxG.width,
			"Game has detected a high DPI display\nand you have set a custom render resolution.\nDo you want to keep the current DPI scaling\nand disable custom resolution?");
		warnText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		texts.add(warnText);

		final keys = ["Yes", "No"];
		for (i in 0...keys.length) {
			final button = new FlxText(0, 0, FlxG.width, keys[i]);
			button.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
			button.y = (warnText.y + warnText.height) + 24;
			button.x += (128 * i) - 80;
			texts.add(button);
		}

		FlxTween.tween(texts, {alpha: 1.0}, 0.5, {
			onComplete: (_) -> updateItems()
		});
	}

	override function update(elapsed:Float)
	{
		if(leftState) {
			super.update(elapsed);
			return;
		}
		var back:Bool = controls.BACK;
		if (controls.UI_LEFT_P || controls.UI_RIGHT_P) {
			FlxG.sound.play(Paths.sound("scrollMenu"), 0.7);
			isYes = !isYes;
			updateItems();
		}
		if (controls.ACCEPT || back) {
			leftState = true;
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			if(!back) {
				// 用户选择 Yes：保留 DPI 缩放，关闭自定义分辨率
				ClientPrefs.data.useDpiSettings = true;
				ClientPrefs.data.renderResolution = -1;
				ClientPrefs.saveSettings();
                TitleState.fromDpiSetting = true;  // 添加
				FlxG.sound.play(Paths.sound('confirmMenu'));
				final button = texts.members[isYes ? 1 : 2];
				FlxFlicker.flicker(button, 1, 0.1, false, true, function(flk:FlxFlicker) {
					new FlxTimer().start(0.5, function (tmr:FlxTimer) {
						FlxTween.tween(texts, {alpha: 0}, 0.2, {
							onComplete: (_) -> {
								// 应用新设置
								#if (cpp || hl) Main.applyRenderResolution(); #end
								ClientPrefs.data.dpiSettingsAsked = true;
								ClientPrefs.saveSettings();
								MusicBeatState.switchState(new TitleState());
							}
						});
					});
				});
			} else {
				// 用户选择 No：关闭 DPI 缩放，保留自定义分辨率
				ClientPrefs.data.useDpiSettings = false;
				ClientPrefs.saveSettings();
                TitleState.fromDpiSetting = true;  // 添加
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(texts, {alpha: 0}, 1, {
					onComplete: (_) -> {
						// 应用自定义分辨率（基于当前 renderResolution）
						#if (cpp || hl) Main.applyRenderResolution(); #end
						ClientPrefs.data.dpiSettingsAsked = true;
						ClientPrefs.saveSettings();
						MusicBeatState.switchState(new TitleState());
					}
				});
			}
		}
		super.update(elapsed);
	}

	function updateItems() {
		texts.members[1].alpha = isYes ? 1.0 : 0.6;
		texts.members[2].alpha = isYes ? 0.6 : 1.0;
	}
}