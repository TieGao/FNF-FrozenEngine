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
import states.PlayState;

class HitGraph extends Sprite
{
    static inline var AXIS_COLOR:FlxColor = 0xffffff;
    static inline var AXIS_ALPHA:Float = 0.5;
    static inline var KADE_MISS_VALUE:Float = -10000;

    public var history:Array<Dynamic> = [];
    public var bitmap:Bitmap;
    
    var _width:Int;
    var _height:Int;
    var _labels:Array<TextField>;
    var _graphics:Graphics;
    
    // Judgment windows (ms) - Kade Engine defaults
    var _marvelousWindow:Float = 22.5;
    var _sickWindow:Float = 45.0;
    var _goodWindow:Float = 90.0;
    var _badWindow:Float = 135.0;
    var _shitWindow:Float = 166.0;
    
    // Color definitions
    var _marvelousColor:FlxColor = 0xFFD700;    // Gold
    var _sickColor:FlxColor = 0x00FFFF;        // Cyan
    var _goodColor:FlxColor = 0x00FF00;        // Green
    var _badColor:FlxColor = 0xFF6464;         // Light Red
    var _shitColor:FlxColor = 0xFF0000;        // Red
    var _missColor:FlxColor = 0x800000;        // Dark Red

    // To prevent duplicate points for sustain notes
    var _processedNotes:Map<String, Bool> = new Map<String, Bool>();
    var _processedCount:Int = 0;

    public function new(X:Int, Y:Int, Width:Int, Height:Int)
    {
        super();
        x = X;
        y = Y;
        _width = Width;
        _height = Height;
        _labels = [];
        
        _graphics = this.graphics;
        
        // Create bitmap
        var bm = new BitmapData(_width, _height, true, 0x00000000);
        bitmap = new Bitmap(bm);
        addChild(bitmap);
        
        // Create labels
        createLabels();
        
        // Initial drawing
        drawAxes();
        drawGrid();
    }

    function drawAxes():Void
    {
        _graphics.lineStyle(1.0, AXIS_COLOR, AXIS_ALPHA);
        
        // Y axis
        _graphics.moveTo(0.0, 0.0);
        _graphics.lineTo(0.0, _height);
        
        // X axis bottom
        _graphics.moveTo(0.0, _height);
        _graphics.lineTo(_width, _height);
        
        // Center line (0ms)
        _graphics.lineStyle(1.0, FlxColor.WHITE, 0.3);
        var centerY:Float = _height / 2;
        _graphics.moveTo(0.0, centerY);
        _graphics.lineTo(_width, centerY);
    }

    function createLabels():Void
    {
        // Early/Late labels
        var early = createTextField(5, _height - 20, FlxColor.WHITE, 11);
        var late = createTextField(5, 5, FlxColor.WHITE, 11);
        early.text = "Early (-166ms)";
        late.text = "Late (+166ms)";
        addChild(early);
        addChild(late);
        
        // Judgment line labels
        var sickLabel = createTextField(_width - 45, getYFromDiff(-_sickWindow) - 6, _sickColor, 10);
        sickLabel.text = "Sick";
        addChild(sickLabel);
        _labels.push(sickLabel);
        
        var goodLabel = createTextField(_width - 50, getYFromDiff(-_goodWindow) - 6, _goodColor, 10);
        goodLabel.text = "Good";
        addChild(goodLabel);
        _labels.push(goodLabel);
        
        var badLabel = createTextField(_width - 45, getYFromDiff(-_badWindow) - 6, _badColor, 10);
        badLabel.text = "Bad";
        addChild(badLabel);
        _labels.push(badLabel);
        
        var shitLabel = createTextField(_width - 45, getYFromDiff(-_shitWindow) - 6, _shitColor, 10);
        shitLabel.text = "Shit";
        addChild(shitLabel);
        _labels.push(shitLabel);
    }

    function getYFromDiff(diff:Float):Float
    {
        // diff: -166 to +166, top to bottom
        var normalizedY:Float = (diff + _shitWindow) / (_shitWindow * 2.0);
        return _height - (normalizedY * _height);
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

    function drawJudgementLine(diff:Float, color:FlxColor):Void
    {
        var yPos:Float = getYFromDiff(diff);
        
        // Draw solid line
        _graphics.lineStyle(1.0, color, 0.4);
        _graphics.moveTo(0.0, yPos);
        _graphics.lineTo(_width, yPos);
    }

    function drawGrid():Void
    {
        // Draw positive and negative judgment lines
        drawJudgementLine(_marvelousWindow, _marvelousColor);
        drawJudgementLine(-_marvelousWindow, _marvelousColor);
        
        drawJudgementLine(_sickWindow, _sickColor);
        drawJudgementLine(-_sickWindow, _sickColor);
        
        drawJudgementLine(_goodWindow, _goodColor);
        drawJudgementLine(-_goodWindow, _goodColor);
        
        drawJudgementLine(_badWindow, _badColor);
        drawJudgementLine(-_badWindow, _badColor);
        
        drawJudgementLine(_shitWindow, _shitColor);
        drawJudgementLine(-_shitWindow, _shitColor);
    }

    function drawHitData():Void
    {
        if (history.length == 0) {
            return;
        }
        
        // Get song length from PlayState
        var songLength:Float = 180000; // Default 3 minutes
        if (PlayState.instance != null) {
            songLength = PlayState.instance.songLength;
        }
        
        // Show full song from start to end
        var startTime:Float = 0;
        var endTime:Float = songLength;
        var timeRange:Float = endTime - startTime;
        
        if (timeRange <= 0) {
            timeRange = 180000; // Default 3 minutes
            endTime = startTime + timeRange;
        }
        
        var hitCount:Int = 0;
        var missCount:Int = 0;
        
        // Draw each point
        for (i in 0...history.length)
        {
            var hit = history[i];
            if (hit == null || hit.length < 3) {
                continue;
            }
            
            var diff:Dynamic = hit[0];
            var judge:Dynamic = hit[1];
            var time:Float = hit[2];
            
            // Skip points with null judge (invalid data)
            if (judge == null) {
                continue;
            }
            
            // Skip if not in time range (shouldn't happen, but just in case)
            if (time < startTime || time > endTime) {
                continue;
            }
            
            // Calculate X position based on time range
            var xPos:Float = ((time - startTime) / timeRange) * _width;
            xPos = FlxMath.bound(xPos, 3.0, _width - 3.0);
            
            // Check if MISS
            var isMiss:Bool = false;
            var diffFloat:Float = 0.0;
            
            if (Std.isOfType(diff, Float))
            {
                diffFloat = diff;
                // Kade Engine MISS marker
                if (Math.abs(diffFloat - KADE_MISS_VALUE) < 1)
                {
                    isMiss = true;
                }
            }
            else if (Std.isOfType(diff, Int))
            {
                diffFloat = diff;
                if (Math.abs(diffFloat - KADE_MISS_VALUE) < 1)
                {
                    isMiss = true;
                }
            }
            
            if (!isMiss && Std.isOfType(judge, String))
            {
                var judgeStr:String = cast(judge, String).toLowerCase();
                if (judgeStr == "miss")
                {
                    isMiss = true;
                }
            }
            
            if (isMiss)
            {
                // MISS point - dark red circle at top
                var yPos:Float = 20.0;
                _graphics.beginFill(_missColor, 0.9);
                _graphics.drawCircle(xPos, yPos, 4.0);
                _graphics.endFill();
                missCount++;
            }
            else
            {
                // Normal hit point - skip if diff is invalid
                if (Std.isOfType(diff, Float))
                    diffFloat = diff;
                else if (Std.isOfType(diff, Int))
                    diffFloat = diff;
                else {
                    continue;
                }
                
                // Filter extreme values
                if (Math.abs(diffFloat) > 5000) {
                    continue;
                }
                
                // Bound to reasonable range
                diffFloat = FlxMath.bound(diffFloat, -_shitWindow, _shitWindow);
                
                // Calculate Y position
                var yPos:Float = getYFromDiff(diffFloat);
                yPos = FlxMath.bound(yPos, 3.0, _height - 3.0);
                
                // Get color based on diff
                var color:FlxColor = getColorByDiff(diffFloat);
                
                // Draw circle
                _graphics.beginFill(color, 0.8);
                _graphics.drawCircle(xPos, yPos, 3.0);
                _graphics.endFill();
                hitCount++;
            }
        }
    }

    function getColorByDiff(diff:Float):FlxColor
    {
        var absDiff = Math.abs(diff);
        
        if (absDiff <= _marvelousWindow) {
            return _marvelousColor;
        } else if (absDiff <= _sickWindow) {
            return _sickColor;
        } else if (absDiff <= _goodWindow) {
            return _goodColor;
        } else if (absDiff <= _badWindow) {
            return _badColor;
        } else if (absDiff <= _shitWindow) {
            return _shitColor;
        } else {
            return _missColor;
        }
    }
    
    public function addToHistory(diff:Float, judge:String, time:Float, noteData:Int = -1):Void
    {
        // Skip if judge is null (invalid data)
        if (judge == null) {
            return;
        }
        
        // Create unique key for this note to avoid duplicates from sustain notes
        var roundedTime:Int = Std.int(time / 10) * 10; // Round to nearest 10ms
        var noteKey:String = roundedTime + "_" + noteData;
        
        // Only add if we haven't processed this note yet
        if (!_processedNotes.exists(noteKey))
        {
            _processedNotes.set(noteKey, true);
            _processedCount++;
            
            // Limit the size of processed notes map
            if (_processedCount > 200) {
                // Simple cleanup: remove some old keys
                var keys:Array<String> = [];
                for (key in _processedNotes.keys()) {
                    keys.push(key);
                }
                
                // Sort keys to remove oldest ones
                keys.sort(function(a:String, b:String):Int {
                    return Reflect.compare(a, b);
                });
                
                // Remove first 50 keys (oldest)
                var removeCount:Int = Std.int(Math.min(50, keys.length));
                for (i in 0...removeCount) {
                    _processedNotes.remove(keys[i]);
                }
                _processedCount -= removeCount;
            }
            
            // Add to history based on Replay.hx logic
            if (judge.toLowerCase() == "miss")
            {
                // Use Kade Engine MISS marker
                history.push([KADE_MISS_VALUE, "miss", time]);
            }
            else if (Math.abs(diff) > 5000) // Filter abnormal values
            {
                return;
            }
            else
            {
                history.push([diff, judge, time]);
            }
            
            // Limit history size
            if (history.length > 1000) {
                history.shift();
            }
        }
    }

    public function update():Void
    {
        // Clear graphics
        _graphics.clear();
        
        // Clear bitmap
        bitmap.bitmapData.fillRect(bitmap.bitmapData.rect, 0x00000000);
        
        // Redraw everything
        drawAxes();
        drawGrid();
        drawHitData();
        
        // Draw graphics to bitmap
        bitmap.bitmapData.draw(this);
    }
    
    public function clearHistory():Void
    {
        history = [];
        _processedNotes = new Map<String, Bool>();
        _processedCount = 0;
        _graphics.clear();
        bitmap.bitmapData.fillRect(bitmap.bitmapData.rect, 0x00000000);
        
        // Clear labels
        for (label in _labels)
        {
            if (contains(label))
                removeChild(label);
        }
        _labels = [];
        
        // Redraw axes and grid
        drawAxes();
        drawGrid();
        createLabels();
    }
    
    public function destroy():Void
    {
        if (bitmap != null && bitmap.bitmapData != null)
        {
            bitmap.bitmapData.dispose();
            removeChild(bitmap);
            bitmap = null;
        }
        
        history = null;
        _labels = null;
        _graphics = null;
        _processedNotes = null;
    }
}