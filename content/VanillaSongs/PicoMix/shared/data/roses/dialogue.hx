// roses-pico 的开场对话（官方 roses-pico.hxc）
// 注意：Iris 解析不了 `sys.io.File` 这种全限定类路径（resolve 只查短名），
// 必须用 HScript 预置的短名 File / FileSystem（HScript.hx preset 已注入）。
import sys.FileSystem;
import Date;
import cutscenes.DialogueBoxPsych;

function onStartCountdown()
{
    var p = PlayState.instance;
    if (p == null || p.chartingMode) return;
    // 编辑器/重试跳过
    var lastAt = getVar('roses_pico_dialogue_at');
    if (lastAt != null && (Date.now().getTime() - lastAt) < 120000) return;
    if (p.seenCutscene && !p.isStoryMode) return;   // freeplay 死亡重试不重播

    // 对话任何一环出错都放行倒计时，不许卡死
    try
    {
        var dialoguePath = Paths.json('roses/dialogue-pico');
        if (dialoguePath == null || !FileSystem.exists(dialoguePath)) return;
        var raw = File.getContent(dialoguePath);
        var dialogueFile = parseJson(raw);
        if (dialogueFile.dialogue == null || dialogueFile.dialogue.length < 1) return;

        setVar('roses_pico_dialogue_at', Date.now().getTime());
        FlxG.sound.play(Paths.sound('ANGRY_TEXT_BOX'), 1.0);
        p.startDialogue(dialogueFile, null);
        return '##PSYCHLUA_FUNCTIONSTOP';
    }
    catch (e:Dynamic)
    {
        debugPrint('roses dialogue failed: ' + e);
        return;
    }
}
