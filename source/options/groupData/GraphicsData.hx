package options.groupData;

import options.objects.OptionCategory;
import options.Option;
import options.Option.OptionType;

class GraphicsData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Graphics', 'Graphics', 'specIcon');

        var sub = cat.section("Graphics", "Graphics");
        var renderResolution = new Option('Resolution', 'Change the game\'s render resolution.', 'renderResolution', INT);
        renderResolution.minValue = 0;
        renderResolution.maxValue = 3;
        renderResolution.changeValue = 1;
        sub.add(renderResolution);

        sub.add(new Option('Low Quality', 'Reduce graphics for performance', 'lowQuality', BOOL));
        sub.add(new Option('Anti-Aliasing', 'Smoother visuals', 'antialiasing', BOOL));
        sub.add(new Option('dpiScale', 'Scale the game based on your screen\'s DPI', 'useDpiSettings', BOOL));
        sub.add(new Option('Shaders', 'Enable shader effects', 'shaders', BOOL));
        sub.add(new Option('Wide Screen', 'Enable 21:9 widescreen mode', 'wideScreen', BOOL));
        sub.add(new Option('GPU Caching', 'Use GPU for texture caching', 'cacheOnGPU', BOOL));
        sub.add(new Option('Devide Draw And Update', 'Draw and Update in separate threads', 'devideDrawAndUpdate', BOOL));

        var framerate = new Option('Framerate', 'Target framerate', 'framerate', INT);
        framerate.minValue = 60;
        framerate.maxValue = 480;
        framerate.changeValue = 1;
        sub.add(framerate);

        var updaterate = new Option('Update Rate', 'Target update rate', 'updaterate', INT);
        updaterate.minValue = 60;
        updaterate.maxValue = 480;
        updaterate.changeValue = 1;
        sub.add(updaterate);

        sub.add(new Option('Unlimited FPS', 'Remove framerate cap (also for update rate)', 'unlimitedFPS', BOOL));
        sub.add(new Option('FPS Rework', 'Make ur game more smooth', 'fpsRework', BOOL));

        var sub = cat.section('FPSCounter', 'FPS Counter');
        sub.add(new Option('FPS Counter', 'Show FPS counter', 'showFPS', BOOL));
        sub.add(new Option('Show OS', 'Show operating system in FPS Counter', 'showOS', BOOL));
        sub.add(new Option('Show API', 'Show graphics API in FPS Counter', 'showApi', BOOL));
        sub.add(new Option('Show TPS', 'Show ticks per second in FPS Counter', 'showTPS', BOOL));
        sub.add(new Option('Show Memory Peak', 'Show peak memory usage in FPS Counter', 'showMEMPeak', BOOL));

        return cat;
    }
}