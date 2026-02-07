// VaporwaveShader.hx - 修复版本
package shaders;

import flixel.system.FlxAssets.FlxShader;
import flixel.FlxG;

class VaporwaveShader extends FlxShader
{
    // 将 GLSL 代码分割成多个部分
    @:glFragmentHeader('
        #pragma header
        
        // Uniforms for Psych Engine 1.0.4
        uniform float uTime;
    ')
    
    @:glFragmentSource('
        // 常量定义
        const float MAX_DIST = 300.;
        const float MIN_DIST = .01;
        const int MAX_STEP = 200;
        const float OFFS_NORM = .1;
        
        const float blockScale = .3;
        const float speed = 12.;
        
        const vec3 col1 = vec3(.9, .1, .7);
        const vec3 col2 = vec3(.1, .2, .8);
    ')
    
    @:glFragmentSource('
        // 随机数函数
        float rand21(vec2 p)
        {
            return fract(sin(dot(p, vec2(1., 113.)))*43758.5453123);
        }
        
        float rand212(vec2 p)
        {
            if (p.x < 2. && p.x > -3.)
                return 0.;
            return fract(sin(dot(p, vec2(1., 113.)))*43758.5453123);
        }
    ')
    
    @:glFragmentSource('
        // 噪声函数
        float noise_value(vec2 p)
        {
            vec2 ip = floor(p);
            vec2 fp = fract(p);
            float xGEy = step(fp.y, fp.x);
            float v_l = rand212(ip + vec2(0., 0.))*(1. - fp.x) +
                        rand212(ip + vec2(1., 0.))*(fp.x - fp.y) +
                        rand212(ip + vec2(1., 1.))*fp.y;
            float v_u = rand212(ip + vec2(0., 0.))*(1. - fp.y) +
                        rand212(ip + vec2(0., 1.))*(fp.y - fp.x) +
                        rand212(ip + vec2(1., 1.))*fp.x;  
            return mix(v_u, v_l, xGEy);
        }
    ')
    
    @:glFragmentSource('
        float noise_value2(vec2 p)
        {
            vec2 ip = floor(p);
            vec2 fp = fract(p);
            vec2 w = fp*fp*(3. - 2.*fp);
            return mix(mix(rand21(ip + vec2(0., 0.)),
                           rand21(ip + vec2(1., 0.)), w.x),
                       mix(rand21(ip + vec2(0., 1.)),
                           rand21(ip + vec2(1., 1.)), w.x), w.y);
        }
    ')
    
    @:glFragmentSource('
        // 条纹函数
        float stripe(float y, float h, float dt)
        {
            const float e = .005;
            float t01 = fract((uTime + dt)*.1);
            h += t01*.15;
            float dh = (1. - t01)*.01;
            float mask = smoothstep(h - dh*.5, h - dh*.5 - e, y);
            mask += smoothstep(h + dh*.5, h + dh*.5 + e, y);
            return mask;
        }
        
        // 太阳条纹
        float sunStripes(vec2 uv)
        {
            const float start = -.02;
            float delta = 2.;
            float mask = stripe(uv.y, start, 0.);
            mask *= stripe(uv.y, start, delta*1.);
            mask *= stripe(uv.y, start, delta*2.);
            mask *= stripe(uv.y, start, delta*3.);
            mask *= stripe(uv.y, start, delta*4.);
            return mask;
        }
    ')
    
    @:glFragmentSource('
        // 旋转矩阵
        mat2 rot(float a)
        {
            float c = cos(a);
            float s = sin(a);
            return mat2(c, -s, s, c);
        }
        
        // 计算高度
        float calcHeight(vec3 p)
        {
            p.z -= uTime*speed;
            float h = noise_value(p.xz*blockScale - .5)*7.;
            float mask = clamp((abs(p.x) - 5.)/10., 0., 1.);
            return h*mask;
        }
        
        // 距离函数
        float sdPlane(vec3 p, float y)
        {
            float h = calcHeight(p);
            return p.y - y - h;
        }
    ')
    
    @:glFragmentSource('
        float calcDist(vec3 p)
        {
            float d = sdPlane(p, 0.);
            return d*.5;
        }
        
        // 光线步进
        float rayMarch(vec3 ro, vec3 rd)
        {
            float d = 0.;
            float t = 0.;
            
            for(int i = 0; i < MAX_STEP; ++i)
            {
                d = calcDist(ro + rd*t);
                t += d;
                if(d < MIN_DIST || t > MAX_DIST)
                    break;
            }
            return t;
        }
    ')
    
    @:glFragmentSource('
        // 计算法线
        vec3 calcNormal(vec3 p)
        {
            vec3 d0 = vec3(calcDist(p));
            vec2 e = vec2(OFFS_NORM, 0.);
            vec3 d = vec3(calcDist(p + e.xyy), calcDist(p + e.yxy), calcDist(p + e.yyx));
            return normalize(d - d0);
        }
        
        // 计算射线方向
        vec3 calcRayDir(vec3 ro, vec3 c, vec2 uv, float z)
        {
            vec3 f = normalize(c - ro);
            vec3 r = normalize(cross(f, vec3(0., 1., 0.)));
            vec3 u = cross(r, f);
            vec3 i = f*z + r*uv.x + u*uv.y;
            return normalize(i);
        }
    ')
    
    @:glFragmentSource('
        // 分形布朗运动
        float fbm(vec3 p)
        {
            float sum = 0.;
            float a = 1.;
            float s = 1.;
            float v = 0.;
            
            for(int i = 0; i < 4; ++i)
            {
                sum += a;
                v += noise_value2(p.xy*s + vec2(0., uTime*0.07))*a;
                a *= .5;
                s *= 2.;
            }
            return v/sum;
        }
    ')
    
    @:glFragmentSource('
        // 主函数
        void main()
        {
            vec2 uv = (openfl_TextureCoordv * openfl_TextureSize - .5 * openfl_TextureSize.xy) / openfl_TextureSize.y;
            
            vec3 col = vec3(0.);
            vec3 ro = vec3(0., 5., 15.);
            vec3 c = vec3(0., 0., -1.);
            
            vec3 rd = calcRayDir(ro, ro + c, uv, 1.);
            float d = rayMarch(ro, rd);
            
            if(d < MAX_DIST)
            {
                vec3 p = ro + rd*d;
                vec3 normal = calcNormal(p);
                vec3 ldir1 = normalize(vec3(-.3, 1., 1.));
                vec3 ldir2 = normalize(vec3(.3, 1., -1.));
                float nl1 = max(0., dot(normal, ldir1));
                float nl2 = max(0., dot(normal, ldir2));
                
                float distMod = smoothstep(0., 100., d);
                vec3 light = mix(nl1*col1, nl2*col2, distMod)*10.;
                
                col += nl1*col1;
                col += nl2*col2*5.*distMod;
                
                p.z -= uTime*speed;
                float lineWidth = .05;
                float widthMod = smoothstep(100., 50., d)*1.5;
                vec2 fp = fract(p.xz*blockScale + .5*lineWidth + .5);
                if(fp.x < lineWidth || fp.y < lineWidth*widthMod) 
                    col = light*(2. + distMod);
            }
            else
            {
                // 背景效果
                float sun0 = smoothstep(.25, .248, length(uv - vec2(.0, .1)));
                float mask = sunStripes(uv);
                float sun = sun0*mask;
                vec3 sunCol = 10.*mix(vec3(.6, .1, .8)*.2, vec3(1., .6, .0), smoothstep(.0, .35, uv.y));
                
                col += sun*sunCol + (1. - sun)*vec3(.6, .3, .7)*1.;
                
                // 雾效
                float fog = smoothstep(.25, .0, uv.y);
                float n = fbm(vec3(uv*3., uTime*0.07));
                fog *= n*((1. - sun0) + sun0*.7);
                
                col += fog*vec3(.1, .5, .9)*mix(2., 10., fog);
                
                // 星星
                vec2 iuv = floor(uv*16.);
                vec2 fuv = fract(uv*16.);
                vec2 starPos = rand21(iuv) + iuv;
                float starDist = length(uv*16. - starPos);
                float starRnd = rand21(iuv);
                float starSize = mix(.008, .03, starRnd);
                float star = smoothstep(starSize, starSize - .001, starDist)*step(mod(starRnd*100., 2.), .5);
                star *= (1. - sun);
                
                col += star*(sin(starRnd*100. + uTime*0.00314*.5)*.5 + .5)*20.;
    ')
    
    @:glFragmentSource('
                // 星尘
                float starDust = smoothstep(.2, .2 + .5*n, uv.y);
                starDust *= n;
                float starDustMask = noise_value2(uv*2. + .5);
                starDust *= starDustMask;
                
                col += starDust*mix(vec3(.6, .2, .6), vec3(.2, .4, .8), starDustMask)*2.5;
            }
            
            // 最终输出
            gl_FragColor = vec4(col/2.0, 1.0);
        }
    ')
    
    // 添加 uniform 变量声明
    public var time(default, set):Float = 0;
    
    function set_time(value:Float):Float
    {
        if (this.uTime != null && this.uTime.value != null)
        {
            this.uTime.value[0] = value;
        }
        return time = value;
    }
    
    public function new()
    {
        super();
        // 初始化 uniform 变量
        if (this.uTime != null)
        {
            this.uTime.value = [0];
        }
        time = 0;
    }
    
    public function update(elapsed:Float):Void
    {
        // 更新时间
        time += elapsed * 1000; // 转换为毫秒
    }
}