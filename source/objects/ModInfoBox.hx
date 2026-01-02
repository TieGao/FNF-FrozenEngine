package objects;

import flixel.group.FlxSpriteGroup;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.graphics.FlxGraphic;

class ModInfoBox extends FlxSpriteGroup
{
    private var bgTag:FlxSprite;
    private var bgBox:FlxSprite;
    private var nowPlayingText:FlxText;
    private var songNameText:FlxText;
    private var authorText:FlxText;
    private var artSprite:FlxSprite; // 新增：艺术图精灵
    
    private var displaySongName:String;
    private var songAuthor:String;
    private var opponentColor:FlxColor;
    
    private var introTextSize:Int = 20;
    private var introSubTextSize:Int = 20;
    private var introTagWidth:Int = 15;
    private var boxBaseWidth:Int = 370;
    
    public var shouldDisplay(default, null):Bool = false;
    
    public function new(originalSongName:String, opponentColor:FlxColor)
    {
        super();
        
        this.opponentColor = opponentColor;
        this.displaySongName = originalSongName;
        
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
            
            if (content != null && content.length > 0)
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
                                // 忽略其他行，包括艺术图信息
                        }
                        lineCount++;
                    }
                }
                
                if (lineCount >= 2) // 至少需要歌曲名和作者
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
                trace('info.txt is empty');
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
        // 处理多种作者格式
        if (line.startsWith('Composer:'))
            return StringTools.trim(line.substr(9));
        else if (line.startsWith('Composer：')) // 中文冒号
            return StringTools.trim(line.substr(9));
        else if (line.startsWith('Author:'))
            return StringTools.trim(line.substr(7));
        else if (line.startsWith('Artist:'))
            return StringTools.trim(line.substr(7));
        else
            return line; // 直接是作者名
    }
    
    private function createElements():Void
    {
        if (!shouldDisplay) return;
        
        var boxWidth:Int = boxBaseWidth;
        var startX:Float = -boxWidth - introTagWidth;
        
        // 创建彩色标签
        bgTag = new FlxSprite(startX, 35);
        bgTag.makeGraphic(boxWidth + introTagWidth, 100, opponentColor);
        bgTag.scrollFactor.set();
        add(bgTag);
        
        // 创建黑色背景框
        bgBox = new FlxSprite(startX, 35);
        bgBox.makeGraphic(boxWidth, 100, FlxColor.BLACK);
        bgBox.scrollFactor.set();
        add(bgBox);
        
        // 使用新的 Paths 函数尝试加载艺术图
        var graphic:FlxGraphic = Paths.getSongGraphic(displaySongName);
        
        if (graphic != null)
        {
            try
            {
                // 创建艺术图精灵
                artSprite = new FlxSprite(startX + boxWidth - 80, 50); // 右侧位置
                artSprite.loadGraphic(graphic);
                artSprite.scrollFactor.set();
                
                // 调整大小以适应框的高度
                var scale:Float = 60 / artSprite.height; // 高度限制为60像素
                artSprite.scale.set(scale, scale);
                artSprite.updateHitbox();
                
                // 确保图片在框内
                if (artSprite.x + artSprite.width > startX + boxWidth - 5)
                {
                    artSprite.x = startX + boxWidth - artSprite.width - 5;
                }
                
                add(artSprite);
                trace('Successfully loaded art for: $displaySongName');
            }
            catch (e:Dynamic)
            {
                trace('Error creating art sprite: $e');
                artSprite = null;
            }
        }
        else
        {
            artSprite = null;
        }
        
        // 如果有艺术图，调整文本宽度
        var textWidth:Int = artSprite != null ? boxWidth - 100 : boxWidth - 20;
        
        // 文本位置计算
        var textStartX:Float = startX + 10;
        
        // 创建"Now Playing:"文本
        nowPlayingText = new FlxText(textStartX, 40, textWidth, "Now Playing:");
        nowPlayingText.setFormat(Paths.font("vcr.ttf"), introTextSize, FlxColor.WHITE, LEFT);
        nowPlayingText.scrollFactor.set();
        add(nowPlayingText);
        
        // 创建歌曲名文本
        var songNameX:Float = textStartX + 160;
        var songNameWidth:Float = artSprite != null ? 100 : 200; // 如果有艺术图，减小宽度
        songNameText = new FlxText(songNameX, 40, songNameWidth, displaySongName);
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
        if (!shouldDisplay || bgTag == null || bgBox == null) return;
        
        var targetX:Float = 0;
        
        FlxTween.tween(bgTag, {x: targetX}, 1, {ease: FlxEase.circInOut});
        FlxTween.tween(bgBox, {x: targetX}, 1, {ease: FlxEase.circInOut});
        
        // 计算文本的目标位置
        var textTargetX:Float = 10;
        var songNameTargetX:Float = 170;
        var artTargetX:Float = artSprite != null ? (boxBaseWidth - 80) : 0;
        
        FlxTween.tween(nowPlayingText, {x: textTargetX}, 1, {ease: FlxEase.circInOut});
        FlxTween.tween(songNameText, {x: songNameTargetX}, 1, {ease: FlxEase.circInOut});
        FlxTween.tween(authorText, {x: textTargetX}, 1, {ease: FlxEase.circInOut});
        
        // 如果有艺术图，也让它滑入
        if (artSprite != null)
        {
            // 计算最终的艺术图位置
            var finalArtX:Float = boxBaseWidth - artSprite.width - 10;
            FlxTween.tween(artSprite, {x: finalArtX}, 1, {ease: FlxEase.circInOut});
        }
        
        new FlxTimer().start(3, function(tmr:FlxTimer)
        {
            slideOut();
        });
    }
    
    private function slideOut():Void
    {
        var boxWidth:Int = boxBaseWidth;
        var slideOutX:Float = -boxWidth - 150;
        
        FlxTween.tween(bgTag, {x: slideOutX}, 1.5, {ease: FlxEase.circInOut});
        FlxTween.tween(bgBox, {x: slideOutX}, 1.5, {ease: FlxEase.circInOut});
        
        FlxTween.tween(nowPlayingText, {x: slideOutX - 300}, 1.5, {ease: FlxEase.circInOut});
        FlxTween.tween(songNameText, {x: slideOutX - 300}, 1.5, {ease: FlxEase.circInOut});
        FlxTween.tween(authorText, {x: slideOutX - 300}, 1.5, {ease: FlxEase.circInOut});
        
        // 如果有艺术图，也让它滑出
        if (artSprite != null)
        {
            FlxTween.tween(artSprite, {x: slideOutX - 300}, 1.5, {ease: FlxEase.circInOut});
        }
    }
    
    override public function destroy():Void
    {
        if (bgTag != null) bgTag.destroy();
        if (bgBox != null) bgBox.destroy();
        if (nowPlayingText != null) nowPlayingText.destroy();
        if (songNameText != null) songNameText.destroy();
        if (authorText != null) authorText.destroy();
        if (artSprite != null) artSprite.destroy();
        
        bgTag = null;
        bgBox = null;
        nowPlayingText = null;
        songNameText = null;
        authorText = null;
        artSprite = null;
        
        super.destroy();
    }
}