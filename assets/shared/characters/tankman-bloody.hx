// stress（pico）的流血切换
// 原版由 Redheads 事件触发 Tankman 进入 bloody 状态：之后所有 sing / idle 动画改用 -bloody 变体，
// 结尾 hehPrettyGood 也只有 -bloody 版本。引擎把 V-Slice 的 Redheads 转成
// PlayAnimation(redheadsAnim, True)，并在事件分支里直接 playAnim('redheadsAnim')（该动画存在于角色 JSON）。
// 角色脚本只负责：事件触发后把后续基础动画换成 -bloody 后缀。

var isBloody:Bool = false;

function onEvent(name:String, value1:String, value2:String, strumTime:Float)
{
    if (name != 'Play Animation') return;

    var dad = game.dad;
    if (dad == null || dad.curCharacter != 'tankman-bloody') return;

    if (value1 == 'redheadsAnim')
    {
        // 引擎已经 playAnim('redheadsAnim')，这里只翻状态
        isBloody = true;
        return;
    }

    // 流血状态下，事件点名的基础动画若只有 -bloody 变体就改播它
    // （例：hehPrettyGood 在 JSON 里只有 hehPrettyGood-bloody）
    if (isBloody)
    {
        var bloodyName:String = value1 + '-bloody';
        if (dad.animation.getByName(bloodyName) != null)
            dad.playAnim(bloodyName, true);
    }
}

function onUpdate(elapsed:Float)
{
    if (!isBloody) return;

    var dad = game.dad;
    if (dad == null || dad.curCharacter != 'tankman-bloody') return;

    var cur:String = (dad.animation.curAnim != null) ? dad.animation.curAnim.name : '';
    switch (cur)
    {
        case 'idle' | 'singLEFT' | 'singDOWN' | 'singUP' | 'singRIGHT':
            dad.playAnim(cur + '-bloody', true);
    }
}
