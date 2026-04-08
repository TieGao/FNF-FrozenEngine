package backend;

//对象池V2.0，增加了重置对象状态的功能，并且改为队列结构（FIFO）, 还有Funkin Team我早密码
class SpritePool {
    private var pool:Array<FlxSprite> = [];
    private var maxSize:Int;
    
    public function new(maxSize:Int = 20) {
        this.maxSize = maxSize;
    }
    
    public function get():FlxSprite {
    if (pool.length > 0) {
        var obj = pool.shift();
        return obj;
    }
    return null;
}

    public function put(obj:FlxSprite):Void {
        if (pool.length < maxSize) {
            resetObject(obj);
            pool.push(obj); // 加入队列末尾
        } else {
            obj.destroy();
        }
    }
    
    private function resetObject(obj:FlxSprite):Void {
        // 重置基本属性
        obj.alpha = 1;
        obj.visible = true;
        obj.exists = true;
        obj.alive = true;
        obj.active = true;
        obj.velocity.set(0, 0);
        obj.acceleration.set(0, 0);
        obj.scale.set(1, 1);
        obj.color = 0xFFFFFF; // 重置颜色
        obj.angle = 0;
        
        // 取消所有动画
        FlxTween.cancelTweensOf(obj);
    }
    
    public function clear():Void {
        while (pool.length > 0) {
            var obj = pool.shift();
            if (obj != null) obj.destroy();
        }
        pool = [];
    }
}
