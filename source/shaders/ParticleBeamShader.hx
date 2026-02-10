package shaders;

import flixel.system.FlxAssets.FlxShader;

class ParticleBeamShader extends FlxShader
{
    @:glFragmentSource('
        #pragma header
        
        uniform float time;
        uniform vec2 resolution;
        uniform float speed;
        uniform float trail;
        uniform float size;
        uniform float intensity;
        uniform float particleCount;
        
        float rand(float n) {
            return fract(sin(n) * 43758.5453123);
        }
        
        float rand2(vec2 n) {
            return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
        }
        
        void main() {
            vec2 uv = openfl_TextureCoordv;
            vec4 color = texture2D(bitmap, uv);
            
            vec3 particleColor = vec3(0.0, 0.6, 1.0);
            float particleValue = 0.0;
            
            float screenHeight = resolution.y;
            float offsetY = 100.0 / screenHeight;
            
            float upRegion = 160.0 / screenHeight;
            float downRegion = 160.0 / screenHeight;
            
            int maxParticles = int(particleCount * 7.5);
            for (int i = 0; i < maxParticles; i++) {
                float id = float(i);
                bool isUp = mod(id, 2.0) == 0.0;
                
                float seed1 = rand(id * 10.0 + 1.0);
                float seed2 = rand(id * 20.0 + 2.0);
                float seed3 = rand(id * 30.0 + 3.0);
                
                float normalizedPos = float(i) / float(maxParticles - 1);
                
                float lowerLeftBound = -0.1;
                float lowerRightBound = 0.25;
                float upperLeftBound = 0.8;
                float upperRightBound = 1.25;
                
                float startX;
                float startY;
                
                if (isUp) {
                    float regionWidth = upperRightBound - upperLeftBound;
                    startX = upperLeftBound + (seed2 * regionWidth);
                    startY = upRegion * 0.5 - offsetY;
                } else {
                    float regionWidth = lowerRightBound - lowerLeftBound;
                    startX = lowerLeftBound + (seed2 * regionWidth);
                    startY = 1.0 - downRegion * 0.5 + offsetY;
                }
                
                float particleTime = time * speed * (0.7 + seed2 * 0.6) + seed3 * 10.0;
                float t = fract(particleTime);
                
                float currentY;
                float currentX;
                
                if (isUp) {
                    currentY = startY + t * upRegion;
                    currentX = startX - t * 0.2;
                } else {
                    currentY = startY - t * downRegion;
                    currentX = startX + t * 0.2;
                }
                
                vec2 particlePos = vec2(currentX, currentY);
                float dist = distance(uv, particlePos);
                
                float particleSize = size * (0.8 + seed1 * 0.4);
                float mainParticle = 1.0 - smoothstep(0.0, particleSize, dist);
                
                int maxTrail = int(trail);
                for (int j = 1; j <= maxTrail; j++) {
                    float jf = float(j);
                    float trailTime = particleTime - jf * 0.02;
                    float trailT = fract(trailTime);
                    float trailY;
                    float trailX;
                    
                    if (isUp) {
                        trailY = startY + trailT * upRegion;
                        trailX = startX - trailT * 0.2;
                    } else {
                        trailY = startY - trailT * downRegion;
                        trailX = startX + trailT * 0.2;
                    }
                    
                    vec2 trailPos = vec2(trailX, trailY);
                    float trailDist = distance(uv, trailPos);
                    float trailAlpha = 1.0 - (jf / float(maxTrail));
                    float trailParticle = trailAlpha * (1.0 - smoothstep(0.0, particleSize * 2.0, trailDist));
                    mainParticle = max(mainParticle, trailParticle * 0.9);
                }
                
                particleValue += mainParticle * 0.25;
            }
            
            particleValue = min(particleValue, 1.0);
            
            vec3 glow = particleColor * particleValue * intensity;
            
            color.rgb += glow;
            gl_FragColor = color;
        }
    ')
    
    public function new()
    {
        super();
        time.value = [0.0];
        resolution.value = [1280.0, 720.0];
        speed.value = [0.4];
        trail.value = [3.0];
        size.value = [0.004];
        intensity.value = [1.0];
        particleCount.value = [10.0];
    }
    
    public function update(elapsed:Float):Void
    {
        time.value[0] += elapsed;
    }
    
    public function setParams(s:Float, t:Float, sz:Float, i:Float, pc:Float):Void
    {
        speed.value = [s];
        trail.value = [t];
        size.value = [sz];
        intensity.value = [i];
        particleCount.value = [pc];
    }
}