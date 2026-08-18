// substates/StatsSubState.hx
package substates;

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.group.FlxGroup;
    // 定义统计数据类型
    
    typedef StatItem = {
        var label:String;
        var value:String;
    }

class StatsSubState extends MusicBeatSubstate
{
    var leftState:Bool = false;
    var bg:FlxSprite;
    var titleText:FlxText;
    var statsContainer:FlxTypedGroup<FlxText>;
    var currentPage:Int = 0;
    var totalPages:Int = 2;
    
    
    override function create()
    {
        super.create();
        
        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.scrollFactor.set();
        bg.alpha = 0.0;
        add(bg);
        
        statsContainer = new FlxTypedGroup<FlxText>();
        for (text in statsContainer.members)
            text.antialiasing = ClientPrefs.data.antialiasing;
        add(statsContainer);
        
        titleText = new FlxText(0, 20, FlxG.width, 
            Language.getPhrase('stats_title', '=== GAME STATISTICS ==='), 
            32);
        titleText.antialiasing = ClientPrefs.data.antialiasing;
        titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.YELLOW, CENTER);
        titleText.scrollFactor.set();
        titleText.alpha = 0.0;
        add(titleText);
        
        showPage(0);
        
        var hintText:FlxText = new FlxText(0, FlxG.height - 35, FlxG.width,
            Language.getPhrase('stats_hint', '←/→ to switch pages | ESC to close'), 
            18);
        hintText.antialiasing = ClientPrefs.data.antialiasing;
        hintText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.GRAY, CENTER);
        hintText.scrollFactor.set();
        hintText.alpha = 0.0;
        add(hintText);
        
        FlxTween.tween(bg, { alpha: 0.85 }, 0.6, { ease: FlxEase.sineIn });
        FlxTween.tween(titleText, { alpha: 1.0 }, 0.6, { ease: FlxEase.sineIn });
        FlxTween.tween(hintText, { alpha: 1.0 }, 0.6, { ease: FlxEase.sineIn, startDelay: 0.3 });
    }
    
    function showPage(page:Int)
    {
        statsContainer.clear();
        
        var startY:Float = 75;
        var lineHeight:Int = 28;
        var maxWidth:Int = 700;
        var leftX:Int = Std.int((FlxG.width - maxWidth) / 2);
        
        var statsData:Array<StatItem> = [];
        
        if (page == 0) {
            // 第一页：基础统计
            statsData = [
                {label: Language.getPhrase('stats_total_score', 'Total Score'), value: formatNumber(ClientPrefs.data.totalScore)},
                {label: Language.getPhrase('stats_total_plays', 'Total Plays'), value: Std.string(ClientPrefs.data.totalPlays)},
                {label: Language.getPhrase('stats_songs_cleared', 'Songs Cleared'), value: Std.string(ClientPrefs.data.totalSongsCleared)},
                {label: Language.getPhrase('stats_total_playtime', 'Total Playtime'), value: formatPlaytime(Std.int(ClientPrefs.data.totalPlaytime))},
                {label: Language.getPhrase('stats_highest_score', 'Highest Score (Single Song)'), value: formatNumber(ClientPrefs.data.highestScore)},
                {label: Language.getPhrase('stats_highest_combo', 'Highest Combo'), value: Std.string(ClientPrefs.data.highestCombo)},
                {label: Language.getPhrase('stats_best_accuracy', 'Best Accuracy'), value: formatPercent(ClientPrefs.data.bestAccuracy)},
                {label: Language.getPhrase('stats_perfect_clears', 'Perfect Clears'), value: Std.string(ClientPrefs.data.perfectClears)},
                {label: Language.getPhrase('stats_full_combos', 'Full Combos'), value: Std.string(ClientPrefs.data.fullComboCount)}
            ];
        } 
        else if (page == 1) {
            // 第二页：判定统计
            var totalJudgements:Int = ClientPrefs.data.totalMarvelous + ClientPrefs.data.totalSicks + 
                                      ClientPrefs.data.totalGoods + ClientPrefs.data.totalBads + 
                                      ClientPrefs.data.totalShits + ClientPrefs.data.totalMisses;
            
            statsData = [
                {label: Language.getPhrase('stats_marvelous', 'Marvelous'), value: Std.string(ClientPrefs.data.totalMarvelous)},
                {label: Language.getPhrase('stats_sicks', 'Sicks'), value: Std.string(ClientPrefs.data.totalSicks)},
                {label: Language.getPhrase('stats_goods', 'Goods'), value: Std.string(ClientPrefs.data.totalGoods)},
                {label: Language.getPhrase('stats_bads', 'Bads'), value: Std.string(ClientPrefs.data.totalBads)},
                {label: Language.getPhrase('stats_shits', 'Shits'), value: Std.string(ClientPrefs.data.totalShits)},
                {label: Language.getPhrase('stats_misses', 'Misses'), value: Std.string(ClientPrefs.data.totalMisses)},
                {label: "", value: ""},
                {label: Language.getPhrase('stats_total_notes', 'Total Notes Hit'), value: Std.string(totalJudgements - ClientPrefs.data.totalMisses)},
                {label: Language.getPhrase('stats_total_judgements', 'Total Notes'), value: Std.string(totalJudgements)}
            ];
        }
        
        // 创建文字
        for (i in 0...statsData.length)
        {
            var stat = statsData[i];
            var displayText:String = stat.label;
            if (stat.value != "") {
                displayText += ": " + stat.value;
            }
            
            if (stat.label == "") {
                // 分隔线
                var separator:FlxText = new FlxText(leftX, startY + (i * lineHeight), maxWidth, "------------------------", 22);
                separator.antialiasing = ClientPrefs.data.antialiasing;
                separator.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.GRAY, LEFT);
                separator.scrollFactor.set();
                separator.alpha = 0.0;
                statsContainer.add(separator);
                FlxTween.tween(separator, { alpha: 0.6 }, 0.4, { ease: FlxEase.sineIn, startDelay: 0.1 + (i * 0.03) });
            } else {
                var statText:FlxText = new FlxText(leftX, startY + (i * lineHeight), maxWidth, displayText, 22);
                statText.antialiasing = ClientPrefs.data.antialiasing;
                statText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, LEFT);
                statText.scrollFactor.set();
                statText.alpha = 0.0;
                statsContainer.add(statText);
                FlxTween.tween(statText, { alpha: 1.0 }, 0.4, { ease: FlxEase.sineIn, startDelay: 0.1 + (i * 0.03) });
            }
        }
        
        // 添加页面指示器
        var pageText:FlxText = new FlxText(0, FlxG.height - 65, FlxG.width, 
            Language.getPhrase('stats_page', 'Page') + " " + (currentPage + 1) + "/" + totalPages, 18);
        pageText.antialiasing = ClientPrefs.data.antialiasing;
        pageText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.CYAN, CENTER);
        pageText.scrollFactor.set();
        pageText.alpha = 0.0;
        statsContainer.add(pageText);
        FlxTween.tween(pageText, { alpha: 0.8 }, 0.3, { ease: FlxEase.sineIn });
    }
    
    function formatNumber(num:Int):String
    {
        if (num >= 1000000) return Std.int(num / 1000000) + "M";
        if (num >= 1000) return Std.int(num / 1000) + "K";
        return Std.string(num);
    }
    
    function formatPlaytime(seconds:Int):String
    {
        var hours:Int = Math.floor(seconds / 3600);
        var minutes:Int = Math.floor((seconds % 3600) / 60);
        var secs:Int = seconds % 60;
        
        if (hours > 0)
            return hours + "h " + minutes + "m " + secs + "s";
        else if (minutes > 0)
            return minutes + "m " + secs + "s";
        else
            return secs + "s";
    }
    
    function formatPercent(value:Float):String
    {
        return Std.string(Math.round(value * 100) / 100) + "%";
    }
    
    override function update(elapsed:Float)
    {
        if (!leftState)
        {
            // 翻页
            if (controls.UI_LEFT_P) {
                currentPage--;
                if (currentPage < 0) currentPage = totalPages - 1;
                showPage(currentPage);
                FlxG.sound.play(Paths.sound('scrollMenu'));
            }
            if (controls.UI_RIGHT_P) {
                currentPage++;
                if (currentPage >= totalPages) currentPage = 0;
                showPage(currentPage);
                FlxG.sound.play(Paths.sound('scrollMenu'));
            }
            
            if (controls.BACK || FlxG.mouse.justPressedRight)
            {
                leftState = true;
                //FlxG.sound.play(Paths.sound('cancelMenu'));
                
                FlxTween.tween(bg, { alpha: 0.0 }, 0.6, { ease: FlxEase.sineOut });
                
                for (text in statsContainer.members)
                {
                    FlxTween.tween(text, { alpha: 0.0 }, 0.4, { ease: FlxEase.sineOut });
                }
                
                FlxTween.tween(titleText, { alpha: 0.0 }, 0.4, { 
                    ease: FlxEase.sineOut,
                    onComplete: function(twn:FlxTween) {
                        FlxG.state.persistentUpdate = true;
                        close();
                    }
                });
            }
        }
        super.update(elapsed);
    }
}