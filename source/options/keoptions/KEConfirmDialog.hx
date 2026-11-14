package options.keoptions;

import shapeEx.Rect;

/**
 * KEOptionsMenu 的阻塞式确认对话框（confirm 类选项专用，替代原 KEConfirmMenu 子菜单）。
 *
 * 打开后主菜单不吃任何输入（KEOptionsMenu.update 里 subState != null 门禁），
 * Yes 执行回调、No/Esc/右键关闭。交互范式照抄 ResetScoreSubState（左右键切换 + 悬停 + 点击），
 * 视觉用 KE 菜单同款 vcr 字体 + 圆角黑面板。
 */
class KEConfirmDialog extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var panel:Rect;
	var titleText:FlxText;
	var bodyText:FlxText;
	var yesText:FlxText;
	var noText:FlxText;

	var onYes:Bool = false;
	var confirmCb:Void->Void;

	public function new(title:String, body:String, confirmCb:Void->Void)
	{
		super();
		this.confirmCb = confirmCb;

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var pw:Int = Std.int(Math.min(560, FlxG.width * 0.55));

		titleText = new FlxText(0, 0, pw - 40, title, 28);
		titleText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		titleText.scrollFactor.set();

		bodyText = new FlxText(0, 0, pw - 48, body, 20);
		bodyText.setFormat(Paths.font("vcr.ttf"), 20, 0xFFCCCCCC, CENTER, OUTLINE, FlxColor.BLACK);
		bodyText.borderSize = 2;
		bodyText.scrollFactor.set();

		// 面板高度按正文行数自适应
		var ph:Int = Std.int(Math.max(220, titleText.height + bodyText.height + 140));
		var px:Int = Std.int((FlxG.width - pw) / 2);
		var py:Int = Std.int((FlxG.height - ph) / 2 - 20);

		panel = new Rect(px, py, pw, ph, 10, 10, FlxColor.BLACK, 0.92, 2, FlxColor.WHITE);
		panel.scrollFactor.set();
		add(panel);

		titleText.x = px + (pw - titleText.width) / 2;
		titleText.y = py + 18;
		add(titleText);

		bodyText.x = px + (pw - bodyText.width) / 2;
		bodyText.y = titleText.y + titleText.height + 14;
		add(bodyText);

		yesText = new FlxText(0, py + ph - 54, 0, backend.Language.getPhrase('yes', 'Yes'), 28);
		yesText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		yesText.borderSize = 2;
		yesText.scrollFactor.set();
		yesText.screenCenter(X);
		yesText.x -= 150;
		yesText.origin.set(yesText.width / 2, yesText.height / 2); // 缩放围绕中心，不往右偏
		add(yesText);

		noText = new FlxText(0, py + ph - 54, 0, backend.Language.getPhrase('no', 'No'), 28);
		noText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		noText.borderSize = 2;
		noText.scrollFactor.set();
		noText.screenCenter(X);
		noText.x += 150;
		noText.origin.set(noText.width / 2, noText.height / 2);
		add(noText);

		updateOptions();
	}

	override function update(elapsed:Float)
	{
		bg.alpha += elapsed * 1.5;
		if (bg.alpha > 0.6) bg.alpha = 0.6;

		// ---- 鼠标：悬停切换 + 点击确认 ----
		var hoveringYes:Bool = FlxG.mouse.overlaps(yesText, camera);
		var hoveringNo:Bool = FlxG.mouse.overlaps(noText, camera);

		if (hoveringYes && !onYes)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
			onYes = true;
			updateOptions();
		}
		else if (hoveringNo && onYes)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
			onYes = false;
			updateOptions();
		}

		if (FlxG.mouse.justPressed)
		{
			if (hoveringYes)
				executeConfirm();
			else if (hoveringNo)
				closeDialog();
		}

		// ---- 键盘：左右切换 / Esc 取消 / Enter 确认 ----
		if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			onYes = !onYes;
			updateOptions();
		}
		if (controls.BACK || FlxG.mouse.justPressedRight)
		{
			closeDialog();
		}
		else if (controls.ACCEPT)
		{
			executeConfirm();
		}

		super.update(elapsed);
	}

	function executeConfirm():Void
	{
		if (onYes && confirmCb != null)
			confirmCb();
		FlxG.sound.play(Paths.sound('cancelMenu'), 0.8);
		close();
	}

	function closeDialog():Void
	{
		FlxG.sound.play(Paths.sound('cancelMenu'), 0.8);
		close();
	}

	function updateOptions():Void
	{
		var scales:Array<Float> = [0.85, 1];
		var alphas:Array<Float> = [0.6, 1];

		yesText.alpha = alphas[onYes ? 1 : 0];
		yesText.scale.set(scales[onYes ? 1 : 0], scales[onYes ? 1 : 0]);
		noText.alpha = alphas[onYes ? 0 : 1];
		noText.scale.set(scales[onYes ? 0 : 1], scales[onYes ? 0 : 1]);
	}
}
