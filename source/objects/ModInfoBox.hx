package objects;

import flixel.group.FlxSpriteGroup;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.graphics.FlxGraphic;

import backend.SongArtConfig;
import backend.Mods;
import backend.Paths;

class ModInfoBox extends FlxSpriteGroup
{
    private var bgTag:FlxSprite;      // 主彩色条（变短）
    private var bgTail:FlxSprite;     // 拖尾彩色条（更长）
    private var bgBox:FlxSprite;      // 黑色背景框
    private var nowPlayingText:FlxText;
    private var songNameText:FlxText;
    private var authorText:FlxText;
    private var artSprite:FlxSprite;
    
    private var displaySongName:String;
    private var songAuthor:String;
    private var opponentColor:FlxColor;
    
    private var introTextSize:Int = 18;
    private var introSubTextSize:Int = 18;
    private var introTagWidth:Int = 18;    
    private var tailTagWidth:Int = 560;      
    private var boxBaseWidth:Int = 400;    
    
    public var shouldDisplay(default, null):Bool = false;
    private var modDirectory:String;
    
    public function new(originalSongName:String, opponentColor:FlxColor, ?modDirectory:String = null)
    {
        super();
        
        this.opponentColor = opponentColor;
        this.displaySongName = originalSongName;
        this.modDirectory = modDirectory;
        
        // 确保SongArtConfig已加载
        if (SongArtConfig.songArts.length == 0) {
            SongArtConfig.loadAllConfigs();
        }
        
        // 检查 info.txt 文件
        var formattedSongName:String = Paths.formatToSongPath(originalSongName);
        var infoPath:String = 'data/${formattedSongName}/info.txt';
        
        if (Paths.fileExists(infoPath, TEXT))
        {
            shouldDisplay = true;
            parseInfoFile(originalSongName);
            
            if (shouldDisplay)
            {
                createElements();
            }
        }
    }
    
    private function parseInfoFile(originalSongName:String):Void
    {
        try
        {
            var formattedSongName:String = Paths.formatToSongPath(originalSongName);
            var content:String = Paths.getTextFromFile('data/${formattedSongName}/info.txt');
            
            if (content != null && content.length > 0 && ClientPrefs.data.modInfoBox)
            {
                var lines:Array<String> = content.split('\n');
                var lineCount:Int = 0;
                
                for (line in lines)
                {
                    var trimmedLine:String = StringTools.trim(line);
                    if (trimmedLine.length > 0)
                    {
                        switch(lineCount)
                        {
                            case 0: // 第一行：歌曲名
                                displaySongName = trimmedLine;
                                
                            case 1: // 第二行：作者
                                songAuthor = parseAuthorLine(trimmedLine);
                                
                            default:
                                // 忽略其他行
                        }
                        lineCount++;
                    }
                }
                
                if (lineCount >= 2) 
                {
                    trace('Parsed info.txt successfully:');
                    trace('  Song: $displaySongName');
                    trace('  Author: $songAuthor');
                }
                else
                {
                    shouldDisplay = false;
                    trace('info.txt has insufficient lines: $lineCount');
                }
            }
            else
            {
                shouldDisplay = false;
                trace('info.txt is empty or modInfoBox display is disabled in options.');
            }
        }
        catch (e:Dynamic)
        {
            trace('Error parsing info.txt: $e');
            shouldDisplay = false;
        }
    }
    
    private function parseAuthorLine(line:String):String
    {

        if (line.startsWith('Composer:'))
            return StringTools.trim(line.substr(9));
        else if (line.startsWith('Composer：')) // 
            return StringTools.trim(line.substr(9));
        else if (line.startsWith('Author:'))
            return StringTools.trim(line.substr(7));
        else if (line.startsWith('Artist:'))
            return StringTools.trim(line.substr(7));
        else
            return line; 
    }
    
    private function createElements():Void
    {
        if (!shouldDisplay) return;
        
        var boxWidth:Int = boxBaseWidth;
        var totalWidth:Int = boxWidth + introTagWidth + tailTagWidth;
        var startX:Float = -totalWidth;
        
        // 创建拖尾彩色条（更长，在右侧）
        bgTail = new FlxSprite(startX + introTagWidth +200, 35);
        bgTail.makeGraphic(tailTagWidth, 100, opponentColor);
        bgTail.scrollFactor.set();
        bgTail.alpha = 0.8; // 稍暗一些
        add(bgTail);
        
        // 创建主彩色条（较短，在最左侧）
        bgTag = new FlxSprite(startX, 35);
        bgTag.makeGraphic(introTagWidth, 100, opponentColor);
        bgTag.scrollFactor.set();
        add(bgTag);
        
        // 创建黑色背景框
        bgBox = new FlxSprite(startX + introTagWidth, 35);
        bgBox.makeGraphic(boxWidth, 100, FlxColor.BLACK);
        bgBox.scrollFactor.set();
        add(bgBox);
        
        // 使用新的SongArtConfig获取艺术图名称
        var artName:String = SongArtConfig.getArtForSong(displaySongName);
        
        if (artName != null)
        {
            try
            {
                // 保存当前模组目录
                var oldModDir = Mods.currentModDirectory;
                
                // 如果提供了模组目录，使用它
                if (modDirectory != null) {
                    Mods.currentModDirectory = modDirectory;
                }
                
                // 尝试加载艺术图
                var graphic:FlxGraphic = Paths.image('songArt/$artName', null, true);
                
                // 恢复模组目录
                Mods.currentModDirectory = oldModDir;
                
                if (graphic != null)
                {
                    // 创建艺术图精灵
                    artSprite = new FlxSprite(startX + introTagWidth + boxWidth - 80, 50);
                    artSprite.loadGraphic(graphic);
                    artSprite.scrollFactor.set();
                    
                    // 调整大小以适应框的高度
                    var scale:Float = 80 / artSprite.height;
                    artSprite.scale.set(scale, scale);
                    artSprite.updateHitbox();
                    
                    // 确保图片在框内
                    if (artSprite.x + artSprite.width > startX + introTagWidth + boxWidth - 5)
                    {
                        artSprite.x = startX + introTagWidth + boxWidth - artSprite.width - 5;
                    }
                    
                    add(artSprite);
                }
                else
                {
                    artSprite = null;
                }
            }
            catch (e:Dynamic)
            {
                artSprite = null;
            }
        }
        else
        {
            artSprite = null;
        }
        
        // 如果有艺术图，调整文本宽度
        var textWidth:Int = artSprite != null ? boxWidth - 40 : boxWidth - 10;
        
        // 文本位置计算
        var textStartX:Float = startX + introTagWidth + 10;
        
        // 创建"Now Playing:"文本
        nowPlayingText = new FlxText(textStartX, 40, textWidth, "Now Playing:");
        nowPlayingText.setFormat(Paths.font("vcr.ttf"), introTextSize, FlxColor.WHITE, LEFT);
        nowPlayingText.scrollFactor.set();
        add(nowPlayingText);
        
        // 创建歌曲名文本
        var songNameX:Float = textStartX + 160;
        var songNameWidth:Float = artSprite != null ? 200 : 200;
        songNameText = new FlxText(songNameX  , 40, songNameWidth, displaySongName);
        songNameText.setFormat(Paths.font("vcr.ttf"), introSubTextSize, FlxColor.WHITE, LEFT);
        songNameText.scrollFactor.set();
        add(songNameText);
        
        // 如果歌曲名太长，调整大小
        if (songNameText.textField.textWidth > songNameWidth - 10)
        {
            var truncatedName:String = songNameText.text;
            while (songNameText.textField.textWidth > songNameWidth - 10 && songNameText.text.length > 10)
            {
                truncatedName = truncatedName.substr(0, truncatedName.length - 1);
                songNameText.text = truncatedName + "...";
            }
        }
        
        // 创建作者文本
        authorText = new FlxText(textStartX, 70, textWidth, songAuthor);
        authorText.setFormat(Paths.font("vcr.ttf"), introSubTextSize, FlxColor.WHITE, LEFT);
        authorText.scrollFactor.set();
        add(authorText);
        
        // 如果作者文本太长，调整大小
        if (authorText.textField.textWidth > textWidth - 10)
        {
            var truncatedAuthor:String = authorText.text;
            while (authorText.textField.textWidth > textWidth - 10 && authorText.text.length > 15)
            {
                truncatedAuthor = truncatedAuthor.substr(0, truncatedAuthor.length - 1);
                authorText.text = truncatedAuthor + "...";
            }
        }
    }
    
    public function slideIn():Void
    {
        if (!shouldDisplay || bgTag == null || bgBox == null || bgTail == null) return;
        
        var targetX:Float = 0;
        
        // 主彩色条和黑色框同时滑入
        FlxTween.tween(bgTag, {x: targetX}, 1, {ease: FlxEase.circInOut,startDelay: 0.25});
        FlxTween.tween(bgBox, {x: targetX + introTagWidth}, 1, {ease: FlxEase.circInOut,startDelay: 0.25});
        
        // 拖尾条稍后滑入，制造延迟效果
        FlxTween.tween(bgTail, {x: targetX + introTagWidth -100 }, 1.2, {
            ease: FlxEase.circInOut,
            startDelay: 0.1
        });
        
        // 计算文本的目标位置
        var textTargetX:Float = introTagWidth + 10;
        var songNameTargetX:Float = introTagWidth + 170;
        
        FlxTween.tween(nowPlayingText, {x: textTargetX}, 1, {ease: FlxEase.circInOut,startDelay: 0.25});
        FlxTween.tween(songNameText, {x: songNameTargetX - 20}, 1, {ease: FlxEase.circInOut,startDelay: 0.25});
        FlxTween.tween(authorText, {x: textTargetX}, 1, {ease: FlxEase.circInOut,startDelay: 0.25});
        
        // 如果有艺术图，也让它滑入
        if (artSprite != null)
        {
            // 计算最终的艺术图位置
            var finalArtX:Float = introTagWidth + boxBaseWidth - artSprite.width - 10;
            FlxTween.tween(artSprite, {x: finalArtX}, 1, {ease: FlxEase.circInOut,startDelay: 0.25});
        }
        
        new FlxTimer().start(3, function(tmr:FlxTimer)
        {
            slideOut();
        });
    }
    
    private function slideOut():Void
    {
        var totalWidth:Int = boxBaseWidth + introTagWidth + tailTagWidth;
        var slideOutX:Float = -totalWidth - 50;
        
        // 拖尾条先滑出，制造拖尾效果
        FlxTween.tween(bgTail, {x: slideOutX + introTagWidth + boxBaseWidth}, 1.2, {
            ease: FlxEase.circInOut,
            startDelay: 0.4
        });
        
        // 主彩色条和黑色框稍后滑出
        FlxTween.tween(bgTag, {x: slideOutX}, 1, {
            ease: FlxEase.circInOut,
            startDelay: 0.2
        });
        
        FlxTween.tween(bgBox, {x: slideOutX + introTagWidth}, 1, {
            ease: FlxEase.circInOut,
            startDelay: 0.2
        });
        
        // 文本和艺术图也稍后滑出
        var textSlideOutX:Float = slideOutX + introTagWidth - 50;
        
        FlxTween.tween(nowPlayingText, {x: textSlideOutX}, 1, {
            ease: FlxEase.circInOut,
            startDelay: 0.2
        });
        
        FlxTween.tween(songNameText, {x: textSlideOutX + 160}, 1, {
            ease: FlxEase.circInOut,
            startDelay: 0.2
        });
        
        FlxTween.tween(authorText, {x: textSlideOutX}, 1, {
            ease: FlxEase.circInOut,
            startDelay: 0.2
        });
        
        // 如果有艺术图，也让它滑出
        if (artSprite != null)
        {
            FlxTween.tween(artSprite, {x: textSlideOutX - 100}, 1, {
                ease: FlxEase.circInOut,
                startDelay: 0.2
            });
        }
    }
    
    override public function destroy():Void
    {
        if (bgTag != null) bgTag.destroy();
        if (bgTail != null) bgTail.destroy();
        if (bgBox != null) bgBox.destroy();
        if (nowPlayingText != null) nowPlayingText.destroy();
        if (songNameText != null) songNameText.destroy();
        if (authorText != null) authorText.destroy();
        if (artSprite != null) artSprite.destroy();
        
        bgTag = null;
        bgTail = null;
        bgBox = null;
        nowPlayingText = null;
        songNameText = null;
        authorText = null;
        artSprite = null;
        
        super.destroy();
    }
}