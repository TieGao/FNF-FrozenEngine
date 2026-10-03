package states.freeplay;

import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.AlbumConfig;
import backend.Paths;
import backend.Mods;

/**
 * Freeplay 右侧的专辑封面展示。
 *
 * 它和 CharacterArtDisplay 占同一个位置、同一个高度档位：FreeplayState 在"这首歌没配
 * characterArt"时才显示它，所以两者不会同时出现，尺寸对齐是为了切换时不跳。
 */
class AlbumArtDisplay extends FlxSprite
{
	private var currentModFolder:String = "";
	private var currentAlbumId:String = "";
	private var isTweening:Bool = false;

	public function new()
	{
		super(FlxG.width + 300, FlxG.height * 0.4);
		antialiasing = ClientPrefs.data.antialiasing;
		scrollFactor.set();
		visible = false;
	}

	/**
	 * 显示专辑封面。返回"是否真的显示了" —— 调用方靠它决定要不要回落到别的展示。
	 */
	public function showAlbum(albumId:String, folder:String, animated:Bool = true):Bool
	{
		if (albumId == null || albumId.length < 1)
		{
			hide();
			return false;
		}

		var album = AlbumConfig.getAlbum(albumId, folder);
		if (album == null)
		{
			hide();
			return false;
		}

		if (currentModFolder == folder && currentAlbumId == albumId && visible)
			return true;

		// 切 mod 目录再取图：Paths.image 的缓存键带 mod 前缀，不切会把图串到别的 mod 上。
		var oldModDir = Mods.currentModDirectory;
		Mods.currentModDirectory = folder;

		var graphic = Paths.image(album.albumArtAsset, null, true);

		Mods.currentModDirectory = oldModDir;

		if (graphic == null)
		{
			hide();
			return false;
		}

		if (isTweening)
		{
			FlxTween.cancelTweensOf(this);
			isTweening = false;
		}

		loadGraphic(graphic);

		// 和 CharacterArtDisplay 的 300 * scale 同档；封面固定 262×262，所以直接按高 300 缩。
		var targetHeight:Float = 300;
		var s:Float = targetHeight / height;
		this.scale.set(s, s);
		updateHitbox();

		var targetX:Float = FlxG.width - width - 50;
		var targetY:Float = (FlxG.height - height) / 2;

		currentModFolder = folder;
		currentAlbumId = albumId;

		y = targetY;

		if (!animated)
		{
			x = targetX;
			alpha = 1;
			visible = true;
			return true;
		}

		x = FlxG.width + 50;
		alpha = 0;
		visible = true;

		isTweening = true;
		FlxTween.tween(this, { x: targetX, alpha: 1 }, 0.3, {
			ease: FlxEase.expoOut,
			onComplete: function(_) { isTweening = false; }
		});
		return true;
	}

	public function hide():Void
	{
		if (isTweening)
		{
			FlxTween.cancelTweensOf(this);
			isTweening = false;
		}
		visible = false;
		currentModFolder = "";
		currentAlbumId = "";
	}
}
