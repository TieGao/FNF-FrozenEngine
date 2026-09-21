package backend;

import flixel.FlxBasic;
import options.objects.OptionInput;

class MouseMove extends FlxBasic
{
    public var allowUpdate:Bool = true;
    public var enableMouseWheel:Bool = true;

    /**
     * 命中判定 / 拖拽基准用的鼠标坐标空间。
     * false（默认）= `FlxG.mouse.x/y`，即相对 `FlxG.camera` 的世界坐标（会被相机滚动推着走）；
     * true = 走 `options.objects.OptionInput` 的指针位置，也就是"宿主界面实际绘制所在的相机"
     * 的坐标空间（与 `FlxObject.overlapsPoint` 的指针侧同一套算法）。
     * 界面把内容按屏幕坐标排版、却画在"不滚动、不缩放"的相机上时要打开它，
     * 否则 mouseLimit 区域与拖拽基准会整体偏掉（scroll 差一个游戏相机的滚动量，
     * zoom != 1 时还多一个缩放误差）。
     */
    public var useViewSpace:Bool = false;

    inline function mouseX():Float return useViewSpace ? OptionInput.mouseX() : FlxG.mouse.x;

    inline function mouseY():Float return useViewSpace ? OptionInput.mouseY() : FlxG.mouse.y;
    
    public var follow:Dynamic; //数据跟谁
    public var followData:String; //数据变量的名称

    public var target:Float;
    public var moveLimit:Array<Float> = [0, 0];  //[min, max]
    public var mouseLimit:Array<Array<Float>> = [];   //[ X[min, max], Y[min, max] ]

    public var mouseWheelSensitivity:Float = -1000.0; // 鼠标滚轮更改量的控制变量
    public var tweenData(default, set):Float = 0; //用于tween/lerp到指定数据的
    private var hasTweenData:Bool = false;
    public var tweenTime:Float = 0.3; //tween时间
    public var tweenType:String = 'linear'; //tween类型
    public var useLerp:Bool = true; //是否使用lerp而不是tween
    public var lerpSmooth:Float = 15; //lerp平滑度

    public var forceUpdateEvent:Bool = true; //是否强制更新事件
    public var event:Void->Void = null;

    ////////////////////////////////////////////////////////////////////////////////////////////////

    public var infScroll:Bool = false; //是否为无限滚动
    
    public var isDragging:Bool = false;
    private var lastMouseY:Float = 0;
    public var velocity:Float = 0; //检测的时候需要它
    private var velocityArray:Array<Float> = [];

    private var __target:Float;
    public var state:String = 'stop';
    
    // 物理参数
    public var dragSensitivity:Float = 1.0;   // 拖动灵敏度
    public var deceleration:Float = 0.9;      // 减速系数 (0.9 - 0.99 效果较好)
    private var minVelocity:Float = 0.001;       // 最小速度阈值
    private var springStrength:Float = 25.0;
    private var releaseBoost:Float = 1.1;

    public var saveElapsed:Float = 0; //保存上一次更新的时间
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    
    public function new(follow:Dynamic, followData:String, moveData:Array<Float>, mouseData:Array<Array<Float>>, putEvent:Void->Void = null, needUpdate:Bool = true) {
        super();
        this.allowUpdate = needUpdate;
        
        this.follow = follow;
        this.followData = followData;

        this.target = Reflect.getProperty(follow, followData); //好像确实没啥用，但是可以用来初始化数据 --狐月影
        if (moveData.length == 0) infScroll = true;
        else this.moveLimit = moveData;
        this.mouseLimit = mouseData;
        
        this.event = putEvent;
    }
    
    private var _lastUpdateTime:Int = 0;
    private var __lastDragTick:Int = 0;
    private var _inertiaTime:Float = 0;
    public var inputAllow:Bool = true;
    private var allowLerp:Bool = false;
    private var _pendingDragDelta:Float = 0;
    public var dragStartDelayMs:Int = 100;
    public var dragStartDistance:Float = 10;
    private var _dragPending:Bool = false;
    private var _dragPendingTick:Int = 0;
    private var _dragPendingY:Float = 0;
   override function update(elapsed:Float) {
    // ========== 原 update 的输入处理 ==========
    if (!allowUpdate) {
        super.update(elapsed);
        return;
    }

    saveElapsed = elapsed;

    var mouse = FlxG.mouse;

    var mx:Float = mouseX();
    var my:Float = mouseY();

    var checkInput:Bool = true;

    if (!(mx > mouseLimit[0][0] && mx < mouseLimit[0][1] && my > mouseLimit[1][0] && my < mouseLimit[1][1])) {
        endDrag();
        _dragPending = false;
        checkInput = false;
    }
    
    if (checkInput && inputAllow) {
        // 鼠标按下
        if (mouse.justPressed) {
            _dragPending = true;
            _dragPendingTick = FlxG.game.ticks;
            _dragPendingY = my;
            lastMouseY = my;
        }

        if (_dragPending && mouse.pressed) {
            var heldMs = FlxG.game.ticks - _dragPendingTick;
            var moved = Math.abs(my - _dragPendingY);
            if (heldMs >= dragStartDelayMs || moved >= dragStartDistance) {
                _dragPending = false;
                startDrag(my);
                cancelMoveTo();
            }
        }

        // 鼠标滚轮
        if (enableMouseWheel && mouse.wheel != 0) {
            isDragging = false;
            _dragPending = false;
            velocity += mouse.wheel * mouseWheelSensitivity;
            cancelMoveTo();
        }
        
        // 拖动中更新位置
        if (isDragging && mouse.pressed) {
            updateDrag(my);
        }

        // 鼠标释放时停止拖动
        if (mouse.justReleased) {
            if (_dragPending) _dragPending = false;
            endDrag();
        }
    } else {
        lastMouseY = my;
        _dragPending = false;
    }

    // ========== 原 drawUpdate 的逻辑合并到这里 ==========
    if (_pendingDragDelta != 0) {
        target += _pendingDragDelta;
        _pendingDragDelta = 0;
    }

    if (!isDragging && Math.abs(velocity) > minVelocity) {
        applyInertia(elapsed);
    }

    if (hasTweenData && allowLerp) {
        if (Math.abs(target - tweenData) < 0.1) {
            target = tweenData;
            tweenData = 0;
            hasTweenData = false;
            allowLerp = false;
        } else {
            target = FlxMath.lerp(tweenData, target, Math.exp(-elapsed * lerpSmooth));
        }
    }

    if (!infScroll) {
        if (target < moveLimit[0]) target = FlxMath.lerp(moveLimit[0], target, Math.exp(-elapsed * lerpSmooth * 2));
        if (target > moveLimit[1]) target = FlxMath.lerp(moveLimit[1], target, Math.exp(-elapsed * lerpSmooth * 2));
    }

    if (__target > target) state = 'up';
    else if (__target < target) state = 'down';
    else if (__target == target) state = 'stop';

    __target = target;

    Reflect.setProperty(follow, followData, target);
    
    if (event != null && (state != 'stop' || forceUpdateEvent)) {
        event();
    }

    super.update(elapsed);
}
    
   // 同样修改 startDrag 中的初始化
private function startDrag(startY:Float) {
    isDragging = true;
    lastMouseY = startY;
    velocLastMouseY = startY;
    _lastUpdateTime = FlxG.game.ticks;
    velocity = 0;
    velocityArray = [];
    __lastDragTick = FlxG.game.ticks;
    _inertiaTime = 0;
    _pendingDragDelta = 0;
}
    
    private var velocLastMouseY:Float = 0;
    private function updateDrag(currentY:Float) {
    // 反转方向：向上拖拽（currentY < lastMouseY）应该让列表向下移动（正delta）
    var deltaY = lastMouseY - currentY;  // 反转：原来 currentY - lastMouseY
    var now = FlxG.game.ticks;
    var deltaMs = Math.max(1, now - __lastDragTick);
    velocity = (deltaY * dragSensitivity) * (1000.0 / deltaMs);
    _pendingDragDelta += deltaY * dragSensitivity;
    lastMouseY = currentY;
    __lastDragTick = now;

    if (FlxG.game.ticks - _lastUpdateTime >= 16)
    {
        var dY = velocLastMouseY - currentY;  // 反转
        var dMs = Math.max(1, FlxG.game.ticks - _lastUpdateTime);
        var vps = (dY * dragSensitivity) * (1000.0 / dMs);
        velocUpdate(vps);
        velocLastMouseY = currentY;
        
        _lastUpdateTime = FlxG.game.ticks;
    }
}

    
    private function endDrag() {
        if (!isDragging) return;
        isDragging = false;
        if (velocLastMouseY != lastMouseY) {
            var dY = lastMouseY - velocLastMouseY;
            var dMs = Math.max(1, FlxG.game.ticks - _lastUpdateTime);
            var vps = (dY * dragSensitivity) * (1000.0 / dMs);
            velocUpdate(vps);
            velocLastMouseY = lastMouseY;
        }
        velocityChange();
        velocity *= releaseBoost;
        _inertiaTime = 0;
    }

    private function set_tweenData(value:Float) {
        var doNotStop:Bool = value == tweenData;
        tweenData = value;
        hasTweenData = true;
        if (!doNotStop) moveTo(tweenData);
        // 目标值没变、但当前位置还没到位时也要重新武装 lerp。
        // 典型场景：静止状态下 tweenData 已被复位成 0，此时再设置 0（比如按 HOME 回到第一个）
        // 会被判成“同值”而跳过 moveTo，allowLerp 一直是 false，导致永远不会滚动过去。
        // （拖拽中不武装，拖拽优先级高于程序化滚动）
        else if (useLerp && !isDragging && Math.abs(target - tweenData) > 0.001) allowLerp = true;

        return tweenData;
    }

    private var moveTween:FlxTween = null;
    private function moveTo(data:Float) {
        if (!useLerp) {
            if (moveTween != null) moveTween.cancel();
            moveTween = FlxTween.num(target, data, tweenTime, {ease:CoolUtil.getTweenEaseByString(tweenType)}, function(v){target = v;});
        } else {
            allowLerp = true;
        }
    }

    private function cancelMoveTo() {
        // 注意顺序：tweenData 是 (default, set) 属性，这里的赋值会走 set_tweenData
        // （可能顺带把 allowLerp 打开），所以这几个标志必须放在它之后再复位。
        tweenData = 0;
        hasTweenData = false;
        allowLerp = false;
        if (moveTween != null) moveTween.cancel();
    }

    /**
     * 丢弃残留的鼠标输入状态（待拖拽 / 拖拽中 / 速度）。
     *
     * 宿主 state 弹出子状态时通常会暂停更新，这段时间内的按下与松开事件都不会被处理，
     * 于是 `_dragPending` 会一直挂着。恢复更新的第一帧就会命中 `_dragPending && mouse.pressed`
     * 而误判成“开始拖拽”，进而调用 `cancelMoveTo()` 把刚设置好的 `tweenData`
     * （例如 Freeplay 搜索结果的跳转）直接取消掉。
     * 因此凡是“暂停更新后即将恢复”的地方，都应该先调用本方法清理一次。
     */
    public function resetInputState():Void
    {
        _dragPending = false;
        isDragging = false;
        _pendingDragDelta = 0;
        velocity = 0;
        velocityArray = [];
        lastMouseY = mouseY();
        velocLastMouseY = lastMouseY;
        _lastUpdateTime = FlxG.game.ticks;
    }

    var isPositive:Bool = true; //正数检测
    private function velocUpdate(data:Float) {
        var zero = Math.abs(data) < minVelocity;
        if (isPositive) {
            if (data > 0) {
                velocityArray = velocityArray.filter(function(v) return Math.abs(v) >= minVelocity);
                velocityArray.push(data);
                if (velocityArray.length > 11) velocityArray.shift();
            } else if (data < 0) {
                velocityArray = [];
                if (!zero) velocityArray.push(data);
                isPositive = false;
            } else {
                velocityArray.push(0);
                if (velocityArray.length > 11) velocityArray.shift();
            }
        } else {
            if (data < 0) {
                velocityArray = velocityArray.filter(function(v) return Math.abs(v) >= minVelocity);
                velocityArray.push(data);
                if (velocityArray.length > 11) velocityArray.shift();
            } else if (data > 0)  {
                velocityArray = [];
                if (!zero) velocityArray.push(data);
                isPositive = true;
            } else {
                velocityArray.push(0);
                if (velocityArray.length > 11) velocityArray.shift();
            }
        }
    }

    private function velocityChange() {
        if (velocityArray.length < 3) {
            velocity = 0;
            return;
        }
        var delete = Std.int(velocityArray.length / 6);
        var sorted = velocityArray.copy();
        sorted.sort(Reflect.compare);
        var low = sorted[delete];
        var high = sorted[sorted.length - 1 - delete];
        var filtered:Array<Float> = [];
        for (v in velocityArray) if (v >= low && v <= high) filtered.push(v);
        if (filtered.length == 0) filtered = velocityArray.copy();
        var sum:Float = 0;
        var weightSum:Float = 0;
        var n = filtered.length;
        for (i in 0...n) {
            var w = Math.pow(1.25, i);
            sum += filtered[i] * w;
            weightSum += w;
        }
        velocity = sum / weightSum;
    }

    private function applyInertia(elapsed:Float) {
        _inertiaTime += elapsed;
        var decelFactor = Math.pow(deceleration, elapsed * 60);
        velocity *= decelFactor;
        if (!infScroll) {
            if (target < moveLimit[0]) {
                var acc = (moveLimit[0] - target) * springStrength;
                velocity += acc * elapsed;
            } else if (target > moveLimit[1]) {
                var acc2 = (moveLimit[1] - target) * springStrength;
                velocity += acc2 * elapsed;
            }
        }
        if (Math.abs(velocity) < minVelocity) {
            velocity = 0;
            return;
        }
        target += velocity * elapsed;
    }
}
