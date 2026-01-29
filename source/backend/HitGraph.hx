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

    public function new(X:Int, Y:Int, Width:Int, Height:Int)
    {
        super();
        x = X;
        y = Y;
        _width = Width;
        _height = Height;
        _labels = [];

        _axis = new Sprite();
        addChild(_axis);

        // 创建早期/晚期标签
        var early = createTextField(10, _height - 20, FlxColor.WHITE, 12);
        var late = createTextField(10, 10, FlxColor.WHITE, 12);
        early.text = "Early (-166ms)";
        late.text = "Late (+166ms)";
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

        var range:Float = 210; // -210ms to +210ms
        var value = (ms + 210) / (range * 2); // 转换到0-1范围

        var pointY = _height - (value * _height);
        gfx.moveTo(0, pointY);
        gfx.lineTo(_width, pointY);
        
        // 添加标签（只在右侧显示一个标签，避免重叠）
        if (labelText != "" && ms > 0) { // 只为正数时间添加标签
            var label = createTextField(_width - 60, pointY - 6, color, 10);
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

        // 绘制判定区域线
        // MARVELOUS 范围: ±22.5ms (金色)
        drawJudgementLine(22.5, FlxColor.fromRGB(255, 215, 0), "Marvelous");
        drawJudgementLine(-22.5, FlxColor.fromRGB(255, 215, 0));
        
        // SICK 范围: ±45ms (蓝色)
        drawJudgementLine(45, FlxColor.CYAN, "Sick");
        drawJudgementLine(-45, FlxColor.CYAN);
        
        // GOOD 范围: ±90ms (绿色)
        drawJudgementLine(90, FlxColor.LIME, "Good");
        drawJudgementLine(-90, FlxColor.LIME);
        
        // BAD 范围: ±135ms (浅红色)
        drawJudgementLine(135, FlxColor.fromRGB(255, 100, 100), "Bad");
        drawJudgementLine(-135, FlxColor.fromRGB(255, 100, 100));
        
        // SHIT 范围: ±166ms (深红色)
        drawJudgementLine(166, FlxColor.RED, "Shit");
        drawJudgementLine(-166, FlxColor.RED);
        
        // MISS线 (±210ms) 使用虚线样式，颜色为暗红色
        drawMissLine(210, FlxColor.fromRGB(128, 0, 0), "Miss");
        drawMissLine(-210, FlxColor.fromRGB(128, 0, 0));
    }

    // 绘制MISS线 - 使用虚线样式
    function drawMissLine(ms:Float, color:FlxColor, labelText:String = ""):Void
    {
        var gfx:Graphics = graphics;
        var dashLength:Float = 5;
        var gapLength:Float = 5;
        
        var range:Float = 210; // -210ms to +210ms
        var value = (ms + 210) / (range * 2); // 转换到0-1范围

        var pointY = _height - (value * _height);
        
        // 绘制虚线
        var currentX:Float = 0;
        var drawingDash:Bool = true;
        
        gfx.lineStyle(1, color, 0.6); // 使用半透明
        
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
        
        // 添加标签（只在右侧显示一个标签，避免重叠）
        if (labelText != "" && ms > 0) {
            var label = createTextField(_width - 60, pointY - 6, color, 10);
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
        var margin = timeRange * 0.05; // 5% 边距
        minTime -= margin;
        maxTime += margin;
        timeRange = maxTime - minTime;
        
        trace('Time range: $minTime - $maxTime (${timeRange}ms)');
        
        // 绘制命中点
        for (i in 0...history.length)
        {
            var diff = history[i][0];
            var judge = history[i][1];
            var time = history[i][2];

            // 根据时间偏移自动确定颜色
            var color = getColorByDiff(diff);
            gfx.beginFill(color, 0.8);
            
            // 转换时间到X坐标 - 使用实际的时间范围
            var xPos = ((time - minTime) / timeRange) * _width;
            
            // 转换时间偏移到Y坐标 - 使用范围 -210ms 到 +210ms
            // 修正Y坐标计算：-210ms对应_height, +210ms对应0
            var normalizedDiff = Math.max(-210, Math.min(210, diff)); // 限制在±210ms内
            var normalized = (normalizedDiff + 210) / 420; // 转换到0-1范围
            var yPos = _height - (normalized * _height);
            
            // 确保在图表范围内
            xPos = FlxMath.bound(xPos, 0, _width);
            yPos = FlxMath.bound(yPos, 0, _height);
            
            // 绘制点 - 所有点大小相同（包括MISS）
            gfx.drawCircle(xPos, yPos, 2);
            gfx.endFill();
        }
        
        trace('Displayed ${history.length} points across ${timeRange}ms time range');
    }

    // 根据时间偏移自动确定颜色 - 修改颜色判定逻辑
    function getColorByDiff(diff:Float):FlxColor
    {
        var absDiff = Math.abs(diff);
        
        if (absDiff <= 22.5) {
            return FlxColor.fromRGB(255, 215, 0); // Marvelous - 金色 (±22.5ms)
        } else if (absDiff <= 45) {
            return FlxColor.CYAN;                 // Sick - 蓝色 (±45ms)
        } else if (absDiff <= 90) {
            return FlxColor.LIME;                 // Good - 绿色 (±90ms)
        } else if (absDiff <= 135) {
            return FlxColor.fromRGB(255, 100, 100); // Bad - 浅红色 (±135ms)
        } else if (absDiff <= 166) {
            return FlxColor.RED;                  // Shit - 深红色 (±166ms)
        } else {
            // MISS - 暗红色
            return FlxColor.fromRGB(128, 0, 0);
        }
    }

    // 保留原有的getJudgeColor函数用于其他用途
    function getJudgeColor(judge:String):FlxColor
    {
        return switch(judge.toLowerCase())
        {
            case "marvelous": FlxColor.fromRGB(255, 215, 0); // 金色
            case "sick": FlxColor.CYAN;                      // 蓝色
            case "good": FlxColor.LIME;                      // 绿色
            case "bad": FlxColor.fromRGB(255, 100, 100);     // 浅红色
            case "shit": FlxColor.RED;                       // 深红色
            case "miss": FlxColor.fromRGB(128, 0, 0);        // 暗红色（MISS）
            default: FlxColor.WHITE;
        }
    }
    
    public function addToHistory(diff:Float, judge:String, time:Float)
    {
        history.push([diff, judge, time]);
    }

    public function update():Void
    {
        // 清除bitmap
        bitmap.bitmapData.fillRect(bitmap.bitmapData.rect, 0x00000000);
        
        trace('HitGraph update: ${history.length} data points');
        
        if (history.length == 0) {
            trace('No history data to display');
            return;
        }
        
        // 清除图形
        graphics.clear();
        
        // 绘制网格和命中数据
        drawGrid();
        drawHitData();
        
        // 重新绘制到bitmap
        bitmap.bitmapData.draw(this);
        
        trace('HitGraph updated successfully');
        
        // 强制重绘
        if (stage != null) {
            stage.invalidate();
        }
    }
}