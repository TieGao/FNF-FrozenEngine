local cutsceneFinished = false
function onCreate()    
    makeFlxAnimateSprite('parentsCutscene')
    loadAnimateAtlas('parentsCutscene', 'christmas/parents_shoot_assets')
    addAnimationBySymbol('parentsCutscene', 'anim', 'parents whole scene')
    setProperty('parentsCutscene.x', -519)
    setProperty('parentsCutscene.y', 503)
    addLuaSprite('parentsCutscene', true)
    setProperty('parentsCutscene.visible', false)
    
    makeFlxAnimateSprite('santaCutscene')
    loadAnimateAtlas('santaCutscene', 'christmas/santa_speaks_assets')
    addAnimationBySymbol('santaCutscene', 'anim', 'santa whole scene')
    setProperty('santaCutscene.x', -460)
    setProperty('santaCutscene.y', 500)
    addLuaSprite('santaCutscene', true)
    setProperty('santaCutscene.visible', false)

    if version >= '1.0' then
        createInstance('skipSprite', 'flixel.addons.display.FlxPieDial', {0, 0, 40, FlxColor('WHITE'), nil, 40, true, 24})
        callMethod('skipSprite.replaceColor', {FlxColor('BLACK'), FlxColor('TRANSPARENT')})
        setObjectCamera('skipSprite', 'camOther')
        addLuaSprite('skipSprite')
        setProperty('skipSprite.x', screenWidth - (getProperty('skipSprite.width') + 80))
        setProperty('skipSprite.y', screenHeight - (getProperty('skipSprite.height') + 72))
        setProperty('skipSprite.amount', 0)
    end
end

function onEndSong()
    if cutsceneFinished == false then
        if stringEndsWith(curStage, 'Erect') then
            santaPrefix = ''
            if shadersEnabled == true then
                for i, object in ipairs({'parentsCutscene', 'santaCutscene'}) do
                    setSpriteShader(object, 'adjustColor')
                    setShaderFloat(object, 'hue', 5)
                    setShaderFloat(object, 'saturation', 20)
                    setShaderFloat(object, 'contrast', 0)
                    setShaderFloat(object, 'brightness', 0)
                end
            end
        else
            santaPrefix = 'stages[0].'
        end
        setProperty(santaPrefix..'santa.visible', false)
        setProperty('santaCutscene.visible', true)
        playAnim('santaCutscene', 'anim', true)
        playSound('santa_emotion', 1, 'cutsceneSound')
        playCutscene()
        return Function_Stop
    end
    return Function_Continue
end

function playCutscene()
    setProperty('inCutscene', true)
    setProperty('boyfriend.stunned', true)
    setProperty('dad.stunned', true)
    setProperty('gf.stunned', true)
    setProperty('camFollow.x', getProperty('santaCutscene.x') + 300 - screenWidth / 2)
    setProperty('camFollow.y', getProperty('santaCutscene.y') - 110 - screenHeight / 2)
    startTween('moveCamera', 'camGame.scroll', {x = getProperty('camFollow.x'), y = getProperty('camFollow.y')}, 2.8, {ease = 'expoOut'})
    doTweenZoom('zoomOutCamera', 'camGame', 0.73, 2, 'expoOut')
    runTimer('parentsLookSanta', 28 / 24)
    runTimer('moveCam', 2.8)
    runTimer('santaDies', 11.375)
    runTimer('camShake', 12.83)
    runTimer('endCutscene', 15)
end

-- Skip cutscene behaviour. Exclusive to 1.0.x versions.
local holdingTime = 0
function onUpdatePost(elapsed)
    if getProperty('inCutscene') == true and version >= '1.0' then
        if keyPressed('accept') then
            holdingTime = math.max(0, math.min(1, holdingTime + elapsed))
        elseif holdingTime > 0 then
            holdingTime = math.max(0, math.lerp(holdingTime, -0.1, math.bound(elapsed * 3, 0, 1)))
        end
        setProperty('skipSprite.amount', math.min(1, math.max(0, (holdingTime / 1) * 1.025)))
        setProperty('skipSprite.alpha', math.remapToRange(getProperty('skipSprite.amount'), 0.025, 1, 0, 1))

        if holdingTime >= 1 then
            removeLuaSprite('skipSprite')
            cutsceneFinished = true    
            stopSound('cutsceneSound')
            endSong()
        end
    end
end

function onTimerCompleted(tag, loops, loopsLeft)
    if tag == 'parentsLookSanta' then
        setProperty('dad.visible', false)
        setProperty('parentsCutscene.visible', true)
        playAnim('parentsCutscene', 'anim', true, false, 28)
    end
    if tag == 'moveCam' then
        setProperty('camFollow.x', getProperty('santaCutscene.x') + 150 - screenWidth / 2)
        setProperty('camFollow.y', getProperty('santaCutscene.y') - 110 - screenHeight / 2)
        startTween('moveCamera', 'camGame.scroll', {x = getProperty('camFollow.x'), y = getProperty('camFollow.y')}, 9, {ease = 'quartInOut'})
        doTweenZoom('zoomOutCamera', 'camGame', 0.79, 9, 'quadInOut')
    end
    if tag == 'santaDies' then
        playSound('santa_shot_n_falls')
    end
    if tag == 'camShake' then
        cameraShake('camGame', 0.005, 0.2)
        setProperty('camFollow.x', getProperty('santaCutscene.x') + 160 - screenWidth / 2)
        setProperty('camFollow.y', getProperty('santaCutscene.y') - 30 - screenHeight / 2)
        startTween('moveCamera', 'camGame.scroll', {x = getProperty('camFollow.x'), y = getProperty('camFollow.y')}, 5, {ease = 'expoOut'})
    end
    if tag == 'endCutscene' then
        cutsceneFinished = true
        endSong()
    end
end

function math.lerp(a, b, ratio)
    return a + ratio * (b - a) 
end

function math.bound(value, min, max)
    if value < min then
        value = min
    elseif value > max then
        value = max
    end
    return value
end

function math.remapToRange(value, start1, stop1, start2, stop2)
    return start2 + (value - start1) * ((stop2 - start2) / (stop1 - start1))
end