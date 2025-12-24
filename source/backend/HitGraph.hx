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
    static inline var KADE_MISS_VALUE:Float = -10000;

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

        var early = createTextField(10, _height - 20, FlxColor.WHITE, 12);
        var late = createTextField(10, 10, FlxColor.WHITE, 12);
        early.text = "Early (-166ms)";
        late.text = "Late (+166ms)";
        addChild(early);
        addChild(late);

        drawAxes();
        
        var bm = new BitmapData(_width, _height, true, 0x00000000);
        bitmap = new Bitmap(bm);
        addChild(bitmap);
    }

    function drawAxes():Void
    {
        var gfx = _axis.graphics;
        gfx.clear();
        gfx.lineStyle(1.0, AXIS_COLOR, AXIS_ALPHA);

        gfx.moveTo(0.0, 0.0);
        gfx.lineTo(0.0, _height);

        gfx.moveTo(0.0, _height);
        gfx.lineTo(_width, _height);

        gfx.moveTo(0.0, _height / 2);
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
        gfx.lineStyle(1.0, color, 0.4);

        var range:Float = 210.0;
        var value = (ms + 210.0) / (range * 2.0);

        var pointY = _height - (value * _height);
        gfx.moveTo(0.0, pointY);
        gfx.lineTo(_width, pointY);
        
        if (labelText != "" && ms > 0.0) {
            var label = createTextField(_width - 60.0, pointY - 6.0, color, 10);
            label.text = labelText;
            addChild(label);
            _labels.push(label);
        }
    }

    function drawGrid():Void
    {
        var gfx:Graphics = graphics;
        gfx.clear();

        for (label in _labels) {
            if (contains(label)) {
                removeChild(label);
            }
        }
        _labels = [];

        drawJudgementLine(22.5, FlxColor.fromRGB(255, 215, 0), "Marvelous");
        drawJudgementLine(-22.5, FlxColor.fromRGB(255, 215, 0));
        
        drawJudgementLine(45.0, FlxColor.CYAN, "Sick");
        drawJudgementLine(-45.0, FlxColor.CYAN);
        
        drawJudgementLine(90.0, FlxColor.LIME, "Good");
        drawJudgementLine(-90.0, FlxColor.LIME);
        
        drawJudgementLine(135.0, FlxColor.fromRGB(255, 100, 100), "Bad");
        drawJudgementLine(-135.0, FlxColor.fromRGB(255, 100, 100));
        
        drawJudgementLine(166.0, FlxColor.RED, "Shit");
        drawJudgementLine(-166.0, FlxColor.RED);
        
        drawMissLine(210.0, FlxColor.fromRGB(128, 0, 0), "Miss");
        drawMissLine(-210.0, FlxColor.fromRGB(128, 0, 0));
    }

    function drawMissLine(ms:Float, color:FlxColor, labelText:String = ""):Void
    {
        var gfx:Graphics = graphics;
        var dashLength:Float = 5.0;
        var gapLength:Float = 5.0;
        
        var range:Float = 210.0;
        var value = (ms + 210.0) / (range * 2.0);

        var pointY = _height - (value * _height);
        
        var currentX:Float = 0.0;
        var drawingDash:Bool = true;
        
        gfx.lineStyle(1.0, color, 0.6);
        
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
        
        if (labelText != "" && ms > 0.0) {
            var label = createTextField(_width - 60.0, pointY - 6.0, color, 10);
            label.text = labelText;
            addChild(label);
            _labels.push(label);
        }
    }

    function drawHitData():Void
    {
        var gfx:Graphics = graphics;
        
        if (history.length == 0) return;
        
        var minTime:Float = Math.POSITIVE_INFINITY;
        var maxTime:Float = Math.NEGATIVE_INFINITY;
        
        for (hit in history) {
            var time:Float = Std.parseFloat(Std.string(hit[2]));
            
            if (time < minTime) minTime = time;
            if (time > maxTime) maxTime = time;
        }
        
        if (minTime == maxTime) {
            minTime = 0.0;
            maxTime = FlxG.sound.music != null ? FlxG.sound.music.length : 120000.0;
        }
        
        var timeRange = maxTime - minTime;
        var margin = timeRange * 0.05;
        minTime -= margin;
        maxTime += margin;
        timeRange = maxTime - minTime;
        
        var validPoints = 0;
        var missPoints = 0;
        
        for (i in 0...history.length)
        {
            var diff:Float = Std.parseFloat(Std.string(history[i][0]));
            var judge:String = Std.string(history[i][1]);
            var time:Float = Std.parseFloat(Std.string(history[i][2]));
            
            var isKadeMiss:Bool = (Math.abs(diff + 10000) < 0.1);
            var isMiss:Bool = isKadeMiss || (judge.toLowerCase() == "miss");
            
            if (isMiss) {
                // 修改：绘制普通的红色圆点代替X
                drawMissPointAsDot(time, minTime, timeRange, i);
                missPoints++;
            } else {
                validPoints++;
                
                if (Math.abs(diff) > 500.0) {
                    diff = FlxMath.bound(diff, -210.0, 210.0);
                }
                
                var color = getColorByDiff(diff);
                gfx.beginFill(color, 0.8);
                
                var xPos:Float = ((time - minTime) / timeRange) * _width;
                var yPos:Float = _height / 2 + (diff / 210.0) * (_height / 2);
                
                xPos = FlxMath.bound(xPos, 2.0, _width - 2.0);
                yPos = FlxMath.bound(yPos, 2.0, _height - 2.0);
                
                gfx.drawCircle(xPos, yPos, 2.0);
                gfx.endFill();
            }
        }
        
        // 精简输出：只显示点数统计
        trace('HitGraph: ${history.length} points total (${validPoints} hits, ${missPoints} misses)');
    }

    // 修改：绘制MISS点为普通红色圆点
    function drawMissPointAsDot(time:Float, minTime:Float, timeRange:Float, index:Int):Void
    {
        var gfx:Graphics = graphics;
        var color:FlxColor = FlxColor.fromRGB(128, 0, 0); // 深红色
        
        var xPos:Float = ((time - minTime) / timeRange) * _width;
        // 修改：将MISS点放在图表上方，但仍在图表区域内
        var yPos:Float = 20.0;
        
        xPos = FlxMath.bound(xPos, 3.0, _width - 3.0);
        yPos = FlxMath.bound(yPos, 15.0, _height - 15.0);
        
        // 绘制红色圆点
        gfx.beginFill(color, 0.8);
        gfx.drawCircle(xPos, yPos, 3.0); // 稍微大一点，更明显
        gfx.endFill();
        
    }

    function getColorByDiff(diff:Float):FlxColor
    {
        var absDiff = Math.abs(diff);
        
        if (absDiff <= 22.5) {
            return FlxColor.fromRGB(255, 215, 0);
        } else if (absDiff <= 45.0) {
            return FlxColor.CYAN;
        } else if (absDiff <= 90.0) {
            return FlxColor.LIME;
        } else if (absDiff <= 135.0) {
            return FlxColor.fromRGB(255, 100, 100);
        } else if (absDiff <= 166.0) {
            return FlxColor.RED;
        } else if (absDiff <= 210.0) {
            return FlxColor.ORANGE;
        } else {
            return FlxColor.PURPLE;
        }
    }
    
    public function addToHistory(diff:Float, judge:String, time:Float)
    {
        if (judge == "miss")
        {
            history.push([-210.0, "miss", time]);
        }
        else if (Math.abs(diff) > 5000)
        {
            return;
        }
        else
        {
            history.push([diff, judge, time]);
        }
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
    
    public function clearHistory():Void
    {
        history = [];
        graphics.clear();
        bitmap.bitmapData.fillRect(bitmap.bitmapData.rect, 0x00000000);
        
        for (label in _labels) {
            if (contains(label)) {
                removeChild(label);
            }
        }
        _labels = [];
        
        drawAxes();
 
    }
}