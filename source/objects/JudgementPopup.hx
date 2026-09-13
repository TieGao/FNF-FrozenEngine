package objects;


import backend.Paths;
import backend.Rating;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import states.PlayState;

/** Shared popup skin, rating and animation helpers used by PlayState. */
class JudgementPopup
{
    public static function getUIFolderInfo(stageUI:String, isPixelStage:Bool):{folder:String, antialias:Bool}
    {
        var uiFolder:String = "";
        var customUIPath:String = "";
        var antialias:Bool = ClientPrefs.data.antialiasing;

        if (ClientPrefs.data.customUI != null && ClientPrefs.data.customUI != "")
            customUIPath = ClientPrefs.data.customUI + "/";

        if (stageUI != "normal")
        {
            uiFolder = customUIPath != ""
                ? 'ratings/' + customUIPath + PlayState.uiPrefix + "UI/"
                : PlayState.uiPrefix + "UI/";
            antialias = !isPixelStage;
        }
        else if (customUIPath != "")
        {
            uiFolder = 'ratings/' + customUIPath;
        }

        return {folder: uiFolder, antialias: antialias};
    }

    public static function resolveRating(rating:Rating, ratingFC:String, noteDiff:Float, rawNoteDiff:Float):{imageName:String, useGoldenNumbers:Bool}
    {
        var imageName:String = rating.image;
        var useGoldenNumbers:Bool = false;
        var isForever:Bool = ClientPrefs.data.customUI != null
            && ClientPrefs.data.customUI.toLowerCase().contains("forever");
        if (!isForever)
            return {imageName: imageName, useGoldenNumbers: useGoldenNumbers};

        if (ratingFC == "MFC" || ratingFC == "SFC"
            || (noteDiff <= ClientPrefs.data.marvelousWindow
                && rating.name != "shit" && rating.name != "bad" && rating.name != "good"))
        {
            return {imageName: "marvelous", useGoldenNumbers: true};
        }

        if (rating.name == "good" || rating.name == "bad" || rating.name == "shit")
            imageName = rating.image + (rawNoteDiff > 0 ? "-e" : "-l");

        return {imageName: imageName, useGoldenNumbers: useGoldenNumbers};
    }

    public static function applyStageVelocity(sprite:FlxSprite, stage:String, playbackRate:Float, multiplier:Float = 1.0):Void
    {
        switch (stage)
        {
            case "ejected":
                sprite.velocity.y -= FlxG.random.int(540, 600) * playbackRate * multiplier;
                sprite.velocity.x += multiplier == 1.0
                    ? -FlxG.random.int(-10, 20) * playbackRate
                    : FlxG.random.float(-15, 15) * playbackRate;
            case "airship":
                sprite.velocity.y -= FlxG.random.int(140, 160) * playbackRate * multiplier;
                sprite.velocity.x = FlxG.random.float(-250, -300) * playbackRate;
            case "turbulence":
                sprite.velocity.y -= FlxG.random.int(140, 160) * playbackRate * multiplier;
                sprite.velocity.x = FlxG.random.float(250, 300) * playbackRate;
            default:
                sprite.velocity.y -= FlxG.random.int(140, 175) * playbackRate * multiplier;
                sprite.velocity.x -= FlxG.random.int(0, 10) * playbackRate;
        }
    }
}
