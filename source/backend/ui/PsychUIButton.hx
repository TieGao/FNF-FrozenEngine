package backend.ui;

import backend.ui.PsychUIBox.UIStyleData;

/**
 * 通用按钮控件。
 *
 * 交互参考设置界面的 OptionButton：
 *  - 按下只做视觉反馈（clickStyle + 快速渐变），**不触发 onClick**；
 *  - 松开鼠标时指针仍在按钮上才生效（onClick / CLICK_EVENT / 音效）；
 *  - 按住拖出按钮再松开 = 取消，拖回来仍然可以生效。
 */
class PsychUIButton extends FlxSpriteGroup
{
	public static final CLICK_EVENT = 'button_click';

	public var name:String;
	public var label(default, set):String;
	public var bg:FlxSprite;
	public var text:FlxText;

	public var onChangeState:String->Void;
	public var onClick:Void->Void;

	/** 按住时的配色（按动反馈） */
	public var clickStyle:UIStyleData = {
		bgColor: FlxColor.BLACK,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var hoverStyle:UIStyleData = {
		bgColor: FlxColor.WHITE,
		textColor: FlxColor.BLACK,
		bgAlpha: 1
	};
	public var normalStyle:UIStyleData = {
		bgColor: 0xFFAAAAAA,
		textColor: FlxColor.BLACK,
		bgAlpha: 1
	};

	/** 按下时配色渐变时长（秒），越小反馈越"脆" */
	public var pressTime:Float = 0.05;
	/** 松开 / 悬停变化时配色渐变时长（秒） */
	public var releaseTime:Float = 0.12;

	/** 松手生效时是否播放点击音效 */
	public var playClickSound:Bool = true;
	public var clickSound:String = 'confirmMenu';
	public var clickSoundVolume:Float = 0.6;

	public function new(x:Float = 0, y:Float = 0, label:String = '', ?onClick:Void->Void = null, ?wid:Int = 80, ?hei:Int = 20)
	{
		super(x, y);
		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		add(bg);
		bg.color = 0xFFAAAAAA;
		bg.alpha = 0.6;

		text = new FlxText(0, 0, 1, '');
		text.antialiasing = ClientPrefs.data.antialiasing;
		text.alignment = CENTER;
		add(text);
		resize(wid, hei);
		this.label = label;
		
		this.onClick = onClick;
		forceCheckNext = true;
	}

	/** 按下视觉状态（鼠标按住且指针在按钮上） */
	public var isClicked:Bool = false;
	/** 指针是否悬停在按钮上 */
	public var isHovered:Bool = false;
	public var forceCheckNext:Bool = false;
	public var broadcastButtonEvent:Bool = true;

	/** 鼠标已在按钮上按下且尚未松开（拖出按钮也不会中断） */
	var _pressing:Bool = false;
	var _firstFrame:Bool = true;

	var _targetStyle:UIStyleData;
	var _styleDuration:Float = 0;
	var _appliedBgAlpha:Float = -1;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(_firstFrame)
		{
			_applyStyle(normalStyle);
			_firstFrame = false;
		}

		// 只在鼠标状态可能变化时重新检测悬停
		if(forceCheckNext || FlxG.mouse.justMoved || FlxG.mouse.justPressed || FlxG.mouse.justReleased)
		{
			forceCheckNext = false;
			var wasHover:Bool = isHovered;
			isHovered = FlxG.mouse.overlaps(bg, camera);

			if(isHovered != wasHover && !_pressing)
				_setStyle(isHovered ? hoverStyle : normalStyle, releaseTime);
		}

		// ---------- 按下：只做视觉反馈，不触发 onClick ----------
		if(isHovered && FlxG.mouse.justPressed)
		{
			_pressing = true;
			isClicked = true;
			_setStyle(clickStyle, pressTime);
		}

		// 按住期间：拖出按钮先取消按下视觉，拖回来再恢复
		if(_pressing)
		{
			if(!isHovered && isClicked)
			{
				isClicked = false;
				_setStyle(normalStyle, releaseTime);
			}
			else if(isHovered && !isClicked)
			{
				isClicked = true;
				_setStyle(clickStyle, pressTime);
			}
		}

		// ---------- 松开：指针仍在按钮上才生效 ----------
		if(FlxG.mouse.justReleased)
		{
			var wasPressing:Bool = _pressing;
			_pressing = false;
			isClicked = false;

			_setStyle(isHovered ? hoverStyle : normalStyle, releaseTime);

			if(wasPressing && isHovered)
			{
				if(playClickSound && clickSound != null && clickSound.length > 0)
					FlxG.sound.play(Paths.sound(clickSound), clickSoundVolume);
				if(onClick != null) onClick();
				if(broadcastButtonEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
			}
		}

		_updateStyle(elapsed);
	}

	function _setStyle(style:UIStyleData, duration:Float)
	{
		_targetStyle = style;
		_styleDuration = duration;
	}

	function _applyStyle(style:UIStyleData)
	{
		_setStyle(style, 0);
		if(bg != null)
		{
			bg.color = style.bgColor;
			_applyBgAlpha(style.bgAlpha);
		}
		if(text != null) text.color = style.textColor;
	}

	/** 只在样式的 bgAlpha 变化时才写 bg.alpha，避免每帧覆盖外部设置的透明度 */
	function _applyBgAlpha(value:Float)
	{
		if(_appliedBgAlpha == value) return;
		_appliedBgAlpha = value;
		bg.alpha = value;
	}

	/** 每帧向目标配色靠拢（颜色插值，不碰 alpha） */
	function _updateStyle(elapsed:Float)
	{
		if(_targetStyle == null) return;

		var t:Float = (_styleDuration <= 0) ? 1 : Math.min(1, elapsed / _styleDuration);
		bg.color = FlxColor.interpolate(bg.color, _targetStyle.bgColor, t);
		text.color = FlxColor.interpolate(text.color, _targetStyle.textColor, t);
		_applyBgAlpha(_targetStyle.bgAlpha);
	}

	public function resize(width:Int, height:Int)
	{
		bg.setGraphicSize(width, height);
		bg.updateHitbox();
		text.fieldWidth = width;
		text.x = bg.x;
		text.y = bg.y + height/2 - text.height/2;
	}

	function set_label(v:String)
	{
		if(text != null && text.exists) text.text = v;
		return (label = v);
	}
}

