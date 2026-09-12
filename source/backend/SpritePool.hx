package backend;

//对象池V2.0，增加了重置对象状态的功能，并且改为队列结构（FIFO）, 还有Funkin Team我早密码
class SpritePool {
    private var pool:Array<FlxSprite> = [];
    private var maxSize:Int;
    
    public function new(maxSize:Int = 20) {
        this.maxSize = maxSize;
    }
    
    public function get():FlxSprite {
        return pool.length > 0 ? pool.pop() : null;  // 改成 LIFO
    }

    public function put(obj:FlxSprite):Void {
        if (pool == null || obj == null) return;
        if (pool.length < maxSize) {
            resetObject(obj);
            pool.push(obj);
        } else {
            obj.destroy();
        }
    }

    private function resetObject(obj:FlxSprite):Void {
        obj.alpha = 1;
        obj.visible = true;
        obj.exists = true;
        obj.alive = true;
        obj.active = true;
        obj.velocity.set(0, 0);
        obj.acceleration.set(0, 0);
        obj.scale.set(1, 1);
        obj.offset.set(0, 0);
        obj.flipX = false;
        obj.flipY = false;
        obj.color = 0xFFFFFF;
        obj.angle = 0;
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
