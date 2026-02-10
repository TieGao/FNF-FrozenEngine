package backend;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.display.Graphics;
import flash.text.TextField;
import flash.text.TextFormat;
import openfl.text.TextFieldAutoSize;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.FlxG;
import backend.ClientPrefs;

class HitGraph extends Sprite
{
    static inline var AXIS_COLOR:FlxColor = 0xffffff;
    static inline var AXIS_ALPHA:Float = 0.5;

    public var history:Array<Dynamic> = [];
    public var bitmap:Bitmap;

    var _axis:Sprite;
    var _width:Int;
    var _height:Int;
    var _labels:Array<TextField>;
    
    // 获取ClientPrefs中的判定窗口值
    var marvelousWindow:Float;
    var sickWindow:Float;
    var goodWindow:Float;
    var badWindow:Float;
    // 固定值
    static inline var SHIT_WINDOW:Float = 166;
    static inline var MISS_WINDOW:Float = 210;

    public function new(X:Int, Y:Int, Width:Int, Height:Int)
    {
        super();
        x = X;
        y = Y;
        _width = Width;
        _height = Height;
        _labels = [];
        
        // 获取ClientPrefs中的判定窗口值
        marvelousWindow = ClientPrefs.data.marvelousWindow;
        sickWindow = ClientPrefs.data.sickWindow;
        goodWindow = ClientPrefs.data.goodWindow;
        badWindow = ClientPrefs.data.badWindow;
        
        // 确保窗口值合理（从小到大）
        if (marvelousWindow > sickWindow) marvelousWindow = 22.5;
        if (sickWindow > goodWindow) sickWindow = 45;
        if (goodWindow > badWindow) goodWindow = 90;
        if (badWindow > SHIT_WINDOW) badWindow = 135;

        _axis = new Sprite();
        addChild(_axis);

        // 创建早期/晚期标签 - 使用固定值
        var early = createTextField(10, _height - 20, FlxColor.WHITE, 12);
        var late = createTextField(10, 10, FlxColor.WHITE, 12);
        early.text = 'Early (+${MISS_WINDOW}ms)';
        late.text = 'Late (-${MISS_WINDOW}ms)';
        addChild(early);
        addChild(late);

        drawAxes();
        
        // 初始化bitmap
        var bm = new BitmapData(_width, _height, true, 0x00000000);
        bitmap = new Bitmap(bm);
        addChild(bitmap);
    }

    function drawAxes():Void
    {
        var gfx = _axis.graphics;
        gfx.clear();
        gfx.lineStyle(1, AXIS_COLOR, AXIS_ALPHA);

        // y-Axis
        gfx.moveTo(0, 0);
        gfx.lineTo(0, _height);

        // x-Axis  
        gfx.moveTo(0, _height);
        gfx.lineTo(_width, _height);

        // 中心线
        gfx.moveTo(0, _height / 2);
        gfx.lineTo(_width, _height / 2);
    }

    public static function createTextField(X:Float = 0, Y:Float = 0, Color:FlxColor = FlxColor.WHITE, Size:Int = 12):TextField
    {
        var tf = new TextField();
        tf.x = X;
        tf.y = Y;
        tf.multiline = false;
        tf.wordWrap = false;
        tf.embedFonts = true;
        tf.selectable = false;
        tf.defaultTextFormat = new TextFormat("_sans", Size, Color.to24Bit());
        tf.alpha = Color.alphaFloat;
        tf.autoSize = TextFieldAutoSize.LEFT;
        return tf;
    }

    function drawJudgementLine(ms:Float, color:FlxColor, labelText:String = ""):Void
    {
        var gfx:Graphics = graphics;
        gfx.lineStyle(1, color, 0.4);

        // 使用MISS_WINDOW作为最大范围
        var range:Float = MISS_WINDOW;
        // 转换到0-1范围，考虑正负值
        var value = (ms + MISS_WINDOW) / (range * 2);

        // 倒转Y坐标计算，使正值为下方，负值为上方
        var pointY = (value * _height);
        gfx.moveTo(0, pointY);
        gfx.lineTo(_width, pointY);
        
        // 调整标签位置，正数时间在下，负数时间在上
        if (labelText != "") {
            var labelY = ms > 0 ? pointY - 6 : pointY - 20;
            var label = createTextField(_width - 60, labelY, color, 10);
            label.text = labelText;
            addChild(label);
            _labels.push(label);
        }
    }

    function drawGrid():Void
    {
        var gfx:Graphics = graphics;
        gfx.clear();

        // 清除旧标签
        for (label in _labels) {
            if (contains(label)) {
                removeChild(label);
            }
        }
        _labels = [];

        // 绘制判定区域线 - 使用ClientPrefs中的窗口值
        // MARVELOUS 范围
        drawJudgementLine(marvelousWindow, FlxColor.fromRGB(255, 215, 0));
        drawJudgementLine(-marvelousWindow, FlxColor.fromRGB(255, 215, 0), "Marvelous");
        
        // SICK 范围
        drawJudgementLine(sickWindow, FlxColor.CYAN);
        drawJudgementLine(-sickWindow, FlxColor.CYAN, "Sick");
        
        // GOOD 范围
        drawJudgementLine(goodWindow, FlxColor.LIME);
        drawJudgementLine(-goodWindow, FlxColor.LIME, "Good");
        
        // BAD 范围 - 根据ClientPrefs变化
        drawJudgementLine(badWindow, FlxColor.fromRGB(255, 100, 100));
        drawJudgementLine(-badWindow, FlxColor.fromRGB(255, 100, 100), "Bad");
        
        // SHIT 范围 - 固定166ms
        drawJudgementLine(SHIT_WINDOW, FlxColor.RED);
        drawJudgementLine(-SHIT_WINDOW, FlxColor.RED, "Shit");
        
        // MISS线 - 固定210ms
        drawMissLine(MISS_WINDOW, FlxColor.fromRGB(100, 0, 0));
        drawMissLine(-MISS_WINDOW, FlxColor.fromRGB(100, 0, 0), "Miss");
    }

    // 绘制MISS线 - 使用虚线样式
    function drawMissLine(ms:Float, color:FlxColor, labelText:String = ""):Void
    {
        var gfx:Graphics = graphics;
        var dashLength:Float = 5;
        var gapLength:Float = 5;
        
        // 使用MISS_WINDOW作为最大范围
        var range:Float = MISS_WINDOW;
        var value = (ms + MISS_WINDOW) / (range * 2);

        // 倒转Y坐标计算
        var pointY = (value * _height);
        
        // 绘制虚线
        var currentX:Float = 0;
        var drawingDash:Bool = true;
        
        gfx.lineStyle(1, color, 0.6);
        
        while (currentX < _width) {
            if (drawingDash) {
                gfx.moveTo(currentX, pointY);
                var dashEnd = currentX + dashLength;
                if (dashEnd > _width) dashEnd = _width;
                gfx.lineTo(dashEnd, pointY);
                currentX = dashEnd;
            } else {
                currentX += gapLength;
            }
            drawingDash = !drawingDash;
        }
        
        // 调整标签位置
        if (labelText != "") {
            var labelY = ms > 0 ? pointY - 6 : pointY - 20;
            var label = createTextField(_width - 60, labelY, color, 10);
            label.text = labelText;
            addChild(label);
            _labels.push(label);
        }
    }

    function drawHitData():Void
    {
        var gfx:Graphics = graphics;
        
        if (history.length == 0) return;
        
        // 计算歌曲的实际时间范围
        var minTime:Float = Math.POSITIVE_INFINITY;
        var maxTime:Float = Math.NEGATIVE_INFINITY;
        
        for (hit in history) {
            var time = hit[2];
            if (time < minTime) minTime = time;
            if (time > maxTime) maxTime = time;
        }
        
        // 如果所有时间都相同，设置一个默认范围
        if (minTime == maxTime) {
            minTime = 0;
            maxTime = FlxG.sound.music != null ? FlxG.sound.music.length : 120000;
        }
        
        // 添加一些边距，让点不会紧贴边界
        var timeRange = maxTime - minTime;
        var margin = timeRange * 0.05;
        minTime -= margin;
        maxTime += margin;
        timeRange = maxTime - minTime;
        
        // 绘制命中点
        for (i in 0...history.length)
        {
            var diff = history[i][0];
            var judge = history[i][1];
            var time = history[i][2];

            // 根据时间偏移自动确定颜色 - 使用动态窗口值
            var color = getColorByDiff(diff);
            gfx.beginFill(color, 0.8);
            
            // 转换时间到X坐标
            var xPos = ((time - minTime) / timeRange) * _width;
            
            // 转换时间偏移到Y坐标 - 使用MISS_WINDOW作为最大范围
            var normalizedDiff = Math.max(-MISS_WINDOW, Math.min(MISS_WINDOW, diff));
            var normalized = (normalizedDiff + MISS_WINDOW) / (MISS_WINDOW * 2);
            
            // 倒转Y坐标计算，使正值为下方，负值为上方
            var yPos = normalized * _height;
            
            // 确保在图表范围内
            xPos = FlxMath.bound(xPos, 0, _width);
            yPos = FlxMath.bound(yPos, 0, _height);
            
            // 绘制点
            gfx.drawCircle(xPos, yPos, 2);
            gfx.endFill();
        }
    }

    // 根据时间偏移自动确定颜色 - 使用动态窗口值
    function getColorByDiff(diff:Float):FlxColor
    {
        var absDiff = Math.abs(diff);
        
        if (absDiff <= marvelousWindow) {
            return FlxColor.fromRGB(255, 215, 0); // Marvelous
        } else if (absDiff <= sickWindow) {
            return FlxColor.CYAN;                 // Sick
        } else if (absDiff <= goodWindow) {
            return FlxColor.LIME;                 // Good
        } else if (absDiff <= badWindow) {
            return FlxColor.fromRGB(255, 100, 100); // Bad - 根据ClientPrefs变化
        } else if (absDiff <= SHIT_WINDOW) {
            return FlxColor.RED;                  // Shit - 固定166ms
        } else {
            return FlxColor.fromRGB(128, 0, 0);   // Miss - 固定210ms
        }
    }

    // 保留原有的getJudgeColor函数用于其他用途
    function getJudgeColor(judge:String):FlxColor
    {
        return switch(judge.toLowerCase())
        {
            case "marvelous": FlxColor.fromRGB(255, 215, 0);
            case "sick": FlxColor.CYAN;
            case "good": FlxColor.LIME;
            case "bad": FlxColor.fromRGB(255, 100, 100);
            case "shit": FlxColor.RED;
            case "miss": FlxColor.fromRGB(128, 0, 0);
            default: FlxColor.WHITE;
        }
    }
    
    public function addToHistory(diff:Float, judge:String, time:Float)
    {
        if (diff == 0 && judge == "") {
            return;
        }
        
        history.push([diff, judge, time]);
    }

    public function update():Void
    {
        bitmap.bitmapData.fillRect(bitmap.bitmapData.rect, 0x00000000);
        
        if (history.length == 0) {
            return;
        }
        
        graphics.clear();
        
        drawGrid();
        drawHitData();
        
        bitmap.bitmapData.draw(this);
        
        if (stage != null) {
            stage.invalidate();
        }
    }
}