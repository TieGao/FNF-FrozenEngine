// nene 的 ABot 眼球随 Set Camera Target 事件转向（官方 nene.hxc onSongEvent）
import states.stages.objects.ABotSpeaker;

function onEvent(name, value1, value2, strumTime)
{
    if (name != 'Set Camera Target') return;
    var p = PlayState.instance;
    if (p == null) return;

    var abot = null;
    for (spr in p.members)
    {
        if (spr != null && Std.isOfType(spr, ABotSpeaker)) { abot = spr; break; }
    }
    if (abot == null) return;

    var v = (value1 == null) ? '' : value1.toLowerCase();
    // 官方：char 0（玩家）→ 看右，char 1（对手）→ 看左
    if (v.indexOf('bf') == 0 || v == 'boyfriend') abot.updateABotEye(1);
    else if (v.indexOf('dad') == 0) abot.updateABotEye(0);
}
