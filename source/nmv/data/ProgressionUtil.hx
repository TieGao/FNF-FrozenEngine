package nmv.data;

import backend.Paths;

/**
 * NMV funkin.utils.ProgressionUtil 的最小移植：语料只用 songIsClear
 * （doubletrouble.hx 跳开场演出）。NMV 原版读自己的 Highscore.songCompleted，
 * FE 用 songRatingFC（有 Personal Best 档位记录 = 打过这首歌）作等价判据。
 * Cosmicube / 豆子购买等进度体系是 NMV 专属，不移植。
 */
class ProgressionUtil
{
	public static function songIsClear(song:String, ?difficulty:Dynamic):Bool
	{
		final formatted = Paths.formatToSongPath(song);
		for (key in backend.Highscore.songRatingFC.keys())
			if (key == formatted || StringTools.startsWith(key, formatted + '-')) return true;
		return false;
	}
}
