// NMV 脚本挂载冒烟。放进内容包后进歌，控制台应依次出现 5 条 [nmv-smoke] 输出。
//
// 放置位置二选一：
//   <内容包>/scripts/states/PlayState.hx   —— 该内容包所有歌生效
//   <内容包>/songs/<歌>/test.hx            —— 只对该歌生效
//
// 注意：这是 hscript，不是 Haxe —— 不要编译它。

var ticks:Int = 0;

function onLoad()
{
	trace('[nmv-smoke] onLoad');
}

function onCreatePost()
{
	trace('[nmv-smoke] onCreatePost song=' + songName + ' bpm=' + bpm);
}

function onUpdate(elapsed)
{
	ticks++;
	if (ticks == 60) trace('[nmv-smoke] 60 frames');
}

function onEvent(name, value1, value2)
{
	trace('[nmv-smoke] event=' + name);
}

function onDestroy()
{
	trace('[nmv-smoke] onDestroy');
}
