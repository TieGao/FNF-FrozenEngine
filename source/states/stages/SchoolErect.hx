// SchoolErect.hx - 修复版，参考原版 School 和 SchoolEvil
package states.stages;

import states.stages.objects.*;
import substates.GameOverSubstate;
import objects.BGSprite;
import flixel.addons.effects.FlxTrail;
import shaders.DropShadowShader;
import shaders.WiggleEffect;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

class SchoolErect extends BaseStage
{
    // 普通学校背景
    var bgSky:BGSprite;
    var backTrees:BGSprite;
    var bgSchool:BGSprite;
    var bgStreet:BGSprite;
    var fgTrees:BGSprite;
    var bgTrees:BGSprite;
    var treeLeaves:BGSprite;
    
    // 邪恶学校背景
    var schoolBuildingEvil:BGSprite;
    var girlfreaksEvil:BGSprite;
    
    // 拖尾效果
    var dadTrail:FlxTrail;
    
    // 着色器
    var characterShaders:Map<String, DropShadowShader> = new Map();
    
    // 添加 wiggleEffect 变量声明
    var wiggleEffect:WiggleEffect;

    override function create()
    {
        var _song = PlayState.SONG;
        if(_song.gameOverSound == null || _song.gameOverSound.trim().length < 1) GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pixel';
        if(_song.gameOverLoop == null || _song.gameOverLoop.trim().length < 1) GameOverSubstate.loopSoundName = 'gameOver-pixel';
        if(_song.gameOverEnd == null || _song.gameOverEnd.trim().length < 1) GameOverSubstate.endSoundName = 'gameOverEnd-pixel';
        if(_song.gameOverChar == null || _song.gameOverChar.trim().length < 1) GameOverSubstate.characterName = 'bf-pixel-dead';

        // 根据歌曲选择背景
        if (songName.contains('evil') || songName.contains('thorns')) {
            createEvilSchool();
        } else {
            createNormalSchool();
        }
        
        setDefaultGF('gf-pixel');

        if (songName.startsWith('senpai')) {
            FlxG.sound.playMusic(Paths.music('Lunchbox'), 0);
            FlxG.sound.music.fadeIn(1, 0, 0.8);
        }
        else if (songName.startsWith('roses')) {
            FlxG.sound.play(Paths.sound('ANGRY_TEXT_BOX'));
            if (isStoryMode && !seenCutscene) {
                FlxG.sound.play(Paths.sound('ANGRY'));
            }
        }
    }

    function createNormalSchool()
    {
        // 参考原版 School.hx 的图层顺序
        var repositionShit = -200;
        
        // 最底层：天空
        bgSky = new BGSprite('weeb/erect/weebSky', -164, -78, 0.2, 0.2);
        bgSky.scale.set(PlayState.daPixelZoom, PlayState.daPixelZoom);
        bgSky.updateHitbox();
        add(bgSky);
        bgSky.antialiasing = false;

        // 第二层：后景树
        backTrees = new BGSprite('weeb/erect/weebBackTrees', -242, -80, 0.5, 0.5);
        backTrees.scale.set(PlayState.daPixelZoom, PlayState.daPixelZoom);
        backTrees.updateHitbox();
        add(backTrees);
        backTrees.antialiasing = false;

        // 第三层：学校建筑
        bgSchool = new BGSprite('weeb/erect/weebSchool', -216, -38, 0.75, 0.75);
        bgSchool.scale.set(PlayState.daPixelZoom, PlayState.daPixelZoom);
        bgSchool.updateHitbox();
        add(bgSchool);
        bgSchool.antialiasing = false;

        // 第四层：街道
        bgStreet = new BGSprite('weeb/erect/weebStreet', -200, 6, 1, 1);
        bgStreet.scale.set(PlayState.daPixelZoom, PlayState.daPixelZoom);
        bgStreet.updateHitbox();
        add(bgStreet);
        bgStreet.antialiasing = false;

        // 第五层：前景树（低质量模式下不显示）
        if(!ClientPrefs.data.lowQuality) {
            fgTrees = new BGSprite('weeb/erect/weebTreesBack', -200, 6, 1, 1);
            fgTrees.scale.set(PlayState.daPixelZoom, PlayState.daPixelZoom);
            fgTrees.updateHitbox();
            add(fgTrees);
            fgTrees.antialiasing = false;
        }
    }

    function createEvilSchool()
    {
        // 参考原版 SchoolEvil.hx
        var posX = 400;
        var posY = 200;

        // 邪恶学校背景
        schoolBuildingEvil = new BGSprite('weeb/erect/evilSchoolBG', -275, -20, 0.8, 0.9);
        schoolBuildingEvil.scale.set(6, 6);
        schoolBuildingEvil.updateHitbox();
        schoolBuildingEvil.antialiasing = false;
        add(schoolBuildingEvil);
        
        // 应用 wiggle 效果（高质量模式下）
        if (ClientPrefs.data.shaders && !ClientPrefs.data.lowQuality) {
            applyWiggleEffect();
        }
    }
    
    function applyWiggleEffect()
    {
        if (schoolBuildingEvil != null) {
            wiggleEffect = new WiggleEffect();
            wiggleEffect.effectType = DREAMY; // 对应 Lua 的 effectType = 0
            wiggleEffect.waveSpeed = 2.0;     // uSpeed
            wiggleEffect.waveFrequency = 4.0; // uFrequency
            wiggleEffect.waveAmplitude = 0.017; // uWaveAmplitude
            
            // 将 WiggleEffect 的 shader 应用到精灵
            schoolBuildingEvil.shader = wiggleEffect.shader;
        }
    }

    override function createPost()
    {
        // 参考原版 School.hx 的树动画创建方式
        if (!songName.contains('evil') && !songName.contains('thorns')) {
            // 普通学校版本：添加树动画（在人物后面）
            var repositionShit = -200;
            
            // 树动画 - 使用 FlxSprite 而不是 BGSprite，像原版那样
            bgTrees = new BGSprite('weeb/erect/weebTrees', -806, -1050, 0.85, 0.85);
            bgTrees.scale.set(PlayState.daPixelZoom, PlayState.daPixelZoom);
            bgTrees.updateHitbox();
            bgTrees.antialiasing = false;
            
            // 添加动画 - 修正：使用正确的帧
            bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
            bgTrees.animation.play('treeLoop');
            
            // 将树添加到人物后面
            addBehindGF(bgTrees);
            
            // 花瓣动画（低质量模式下不显示）
            if(!ClientPrefs.data.lowQuality) {
                treeLeaves = new BGSprite('weeb/erect/petals', -20, -40, 0.85, 0.85, ['PETALS ALL'], true);
                treeLeaves.scale.set(PlayState.daPixelZoom, PlayState.daPixelZoom);
                treeLeaves.updateHitbox();
                treeLeaves.antialiasing = false;
                addBehindGF(treeLeaves);
            }
        }
        
        // 检查是否需要鬼魂事件
        if (songName.contains('evil') || songName.contains('thorns')) {
            // 参考原版 SchoolEvil.hx 的拖尾效果
            if (!ClientPrefs.data.lowQuality) {
                dadTrail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069);
                addBehindDad(dadTrail);
            }
            
            // 为角色应用 dropShadow 着色器
            if (ClientPrefs.data.shaders) {
                applyDropShadowToCharacters();
            }
        } else {
            // 普通学校版本的着色器
            if (ClientPrefs.data.shaders) {
                applySchoolDropShadowToCharacters();
            }
        }
    }
    
    function applyDropShadowToCharacters()
    {
        var characters = [boyfriend, dad, gf];
        var characterNames = ['boyfriend', 'dad', 'gf'];
        
        for (i in 0...characters.length) {
            var char = characters[i];
            var name = characterNames[i];
            
            if (char != null) {
                var shader = new DropShadowShader();
                
                // 基础设置（邪恶版本）
                shader.hue.value = [-28.0];
                shader.saturation.value = [-20.0];
                shader.contrast.value = [31.0];
                shader.brightness.value = [-66.0];
                
                shader.ang.value = [Math.PI * 120 / 180]; // 120度转弧度
                shader.str.value = [1.0];
                shader.dist.value = [4.0];
                shader.thr.value = [0.1];
                
                shader.AA_STAGES.value = [0.0];
                shader.dropColor.value = [82/255, 29/255, 75/255];
                
                // GF像素特殊处理
                if (gf != null && gf.curCharacter == 'gf-pixel') {
                    shader.hue.value = [-28.0];
                    shader.saturation.value = [-20.0];
                    shader.contrast.value = [11.0];
                    shader.brightness.value = [-42.0];
                    shader.dist.value = [3.0];
                    shader.thr.value = [0.3];
                }
                
                // DAD特殊处理
                if (name == 'dad') {
                    shader.ang.value = [Math.PI * 105 / 180]; // 105度
                    shader.str.value = [0.34];
                    shader.dist.value = [3.0];
                }
                // GF特殊处理
                else if (name == 'gf') {
                    shader.ang.value = [Math.PI * 90 / 180]; // 90度
                }
                
                // 设置帧边界
                if (char.frame != null && char.frame.uv != null) {
                    shader.uFrameBounds.value = [
                        char.frame.uv.x,
                        char.frame.uv.y,
                        char.frame.uv.width,
                        char.frame.uv.height
                    ];
                }
                
                // 检查并应用遮罩
                var imagePath = char.imageFile;
                if (imagePath != null) {
                    var imageName = imagePath.split('/').pop();
                    var maskPath = 'images/characters/masks/${imageName}_mask.png';
                    
                    if (Paths.fileExists(maskPath, IMAGE)) {
                        shader.useMask.value = [true];
                        shader.thr2.value = [1.0];
                    } else {
                        shader.useMask.value = [false];
                    }
                }
                
                // 监听动画回调以更新帧边界
                char.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int) {
                    if (shader != null && char.frame != null && char.frame.uv != null) {
                        shader.uFrameBounds.value = [
                            char.frame.uv.x,
                            char.frame.uv.y,
                            char.frame.uv.width,
                            char.frame.uv.height
                        ];
                            shader.angOffset.value = [char.frame.angle * Math.PI / 180];
                    }
                };
                
                char.shader = shader;
                characterShaders.set(name, shader);
            }
        }
    }
    
    function applySchoolDropShadowToCharacters()
    {
        var characters = [boyfriend, dad, gf];
        var characterNames = ['boyfriend', 'dad', 'gf'];
        
        for (i in 0...characters.length) {
            var char = characters[i];
            var name = characterNames[i];
            
            if (char != null) {
                var shader = new DropShadowShader();
                
                // 普通学校版本的设置
                shader.hue.value = [-10.0];
                shader.saturation.value = [-23.0];
                shader.contrast.value = [24.0];
                shader.brightness.value = [-66.0];
                
                shader.ang.value = [Math.PI * 90 / 180]; // 90度
                shader.str.value = [1.0];
                shader.dist.value = [5.0];
                shader.thr.value = [0.1];
                
                shader.AA_STAGES.value = [0.0];
                shader.dropColor.value = [82/255, 53/255, 29/255];
                
                // GF像素特殊处理
                if (gf != null && gf.curCharacter == 'gf-pixel') {
                    shader.hue.value = [-10.0];
                    shader.saturation.value = [-25.0];
                    shader.contrast.value = [5.0];
                    shader.brightness.value = [-42.0];
                    shader.dist.value = [3.0];
                    shader.thr.value = [0.3];
                }
                
                // 设置帧边界
                if (char.frame != null && char.frame.uv != null) {
                    shader.uFrameBounds.value = [
                        char.frame.uv.x,
                        char.frame.uv.y,
                        char.frame.uv.width,
                        char.frame.uv.height
                    ];
                }
                
                // 检查并应用遮罩
                var imagePath = char.imageFile;
                if (imagePath != null) {
                    var imageName = imagePath.split('/').pop();
                    var maskPath = 'images/characters/masks/${imageName}_mask.png';
                    
                    if (Paths.fileExists(maskPath, IMAGE)) {
                        shader.useMask.value = [true];
                        shader.thr2.value = [1.0];
                    } else {
                        shader.useMask.value = [false];
                    }
                }
                
                // 监听动画回调
                char.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int) {
                    if (shader != null && char.frame != null && char.frame.uv != null) {
                        shader.uFrameBounds.value = [
                            char.frame.uv.x,
                            char.frame.uv.y,
                            char.frame.uv.width,
                            char.frame.uv.height
                        ];
                        shader.angOffset.value = [char.frame.angle * Math.PI / 180];
                    }
                };
                
                char.shader = shader;
                characterShaders.set(name, shader);
            }
        }
    }

    override function beatHit()
    {
        super.beatHit();
        // 如果有树动画，确保它在播放
        if (bgTrees != null && bgTrees.animation != null) {
            bgTrees.animation.play('treeLoop');
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        // 更新 wiggle 效果时间
        if (wiggleEffect != null) {
            wiggleEffect.update(elapsed);
        }
    }

    // 事件推送 - 参考原版 SchoolEvil.hx
    override function eventPushed(event:objects.Note.EventNote)
    {
        switch(event.event)
        {
            case "Trigger BG Ghouls":
                if(!ClientPrefs.data.lowQuality)
                {
                    girlfreaksEvil = new BGSprite('weeb/bgGhouls', -100, 190, 0.9, 0.9, ['BG freaks glitch instance'], false);
                    girlfreaksEvil.scale.set(PlayState.daPixelZoom, PlayState.daPixelZoom);
                    girlfreaksEvil.updateHitbox();
                    girlfreaksEvil.visible = false;
                    girlfreaksEvil.antialiasing = false;
                    girlfreaksEvil.animation.finishCallback = function(name:String)
                    {
                        if(name == 'BG freaks glitch instance')
                            girlfreaksEvil.visible = false;
                    }
                    addBehindGF(girlfreaksEvil);
                }
        }
    }

    override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
    {
        switch(eventName)
        {
            case "Trigger BG Ghouls":
                if(!ClientPrefs.data.lowQuality && girlfreaksEvil != null)
                {
                    girlfreaksEvil.animation.play('BG freaks glitch instance', true);
                    girlfreaksEvil.visible = true;
                }
        }
    }
}