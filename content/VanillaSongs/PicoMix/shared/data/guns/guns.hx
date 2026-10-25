// {song} 的开场过场视频（官方 ugh.hxc / guns.hxc：仅故事模式）
// 由 PlayState 内容包 per-song 扫描加载（需要 2026-10-19 编译后的引擎）

import sys.FileSystem;
import Date;

function onStartCountdown()
{
    var p = PlayState.instance;
    if (p == null || p.chartingMode) return;
    if (!p.isStoryMode) return;
    // 死亡重试 2 分钟内不重播
    var lastAt = getVar('gunsCutscene_at');
    if (lastAt != null && (Date.now().getTime() - lastAt) < 120000) return;

    var file = Paths.video('gunsCutscene');
    if (!FileSystem.exists(file))
    {
        debugPrint('week7p: video missing: ' + file);
        return;
    }
    setVar('gunsCutscene_at', Date.now().getTime());
    p.inCutscene = true;
    p.startVideo('gunsCutscene', false, true);
    // 预热：让 tankman extra 图集的纹理在倒计时前完成首次上传
    var dad = p.dad;
    if (dad != null && dad.hasAnimation('laugh'))
    {
        dad.playAnim('laugh', true);
        dad.playAnim('idle', true);
    }
    return '##PSYCHLUA_FUNCTIONSTOP';
}
