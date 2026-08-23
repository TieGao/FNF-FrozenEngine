package states.stages;

import states.stages.objects.*;
import objects.AudioDisplay;
import flixel.util.FlxColor;
import flixel.math.FlxMath;

class AudioStage extends StageWeek1
{
	// 波形图显示
	var audioDisplay:AudioDisplay;
	var audioDisplayBG:FlxSprite;
	
	// 波形图参数
	var displayWidth:Int = 1800;
	var displayHeight:Int = 1000;           // 增加高度
	var displayLines:Int = 64;
	var displayGap:Int = 2;
	var displayColor:FlxColor = FlxColor.CYAN;
	
	// 位置偏移
	var displayX:Float = 0;
	var displayY:Float = 0;
	
	override function create()
	{
		super.create();
		
		// 创建波形图
		audioDisplay = new AudioDisplay(
			null,
			displayX - 200, 
			displayY + displayHeight / 2 + 200,
			displayWidth,
			displayHeight,
			displayLines,
			displayGap,
			displayColor,
			false
		);
		audioDisplay.gain = 3.0;            // 提高增益，让波形更高
		add(audioDisplay);
	}
	
	override function startSong()
	{
		super.startSong();
		
		if (FlxG.sound.music != null)
		{
			audioDisplay.changeAnalyzer(FlxG.sound.music);
			audioDisplay.stopUpdate = false;
		}
	}
	
	override function beatHit()
	{
		super.beatHit();
		
		// 每4拍改变颜色
		if (curBeat % 4 == 0)
		{
			var colors:Array<FlxColor> = [
				FlxColor.CYAN,
				FlxColor.LIME,
				FlxColor.MAGENTA,
				FlxColor.ORANGE,
				FlxColor.PURPLE,
				FlxColor.RED,
				FlxColor.YELLOW
			];
			var randomColor = colors[Std.int(Math.random() * colors.length)];
			
			for (member in audioDisplay.members)
			{
				if (member != null) member.color = randomColor;
			}
		}
	}
	
	override function destroy()
	{
		if (audioDisplay != null)
		{
			audioDisplay.destroy();
			audioDisplay = null;
		}
		super.destroy();
	}
}