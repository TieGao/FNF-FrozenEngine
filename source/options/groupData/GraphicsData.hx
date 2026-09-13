package options.groupData;

import options.objects.OptionCategory;
import options.psychoptions.PsychOption;
import options.psychoptions.PsychOption.OptionType;

class GraphicsData
{
    public static function build():OptionCategory
    {
        var cat = new OptionCategory('Graphics', 'Graphics', 'specIcon');

        var sub = cat.section("Graphics", "Graphics");
        var renderResolution = new PsychOption('Resolution', 'Change the game\'s render resolution.', 'renderResolution', INT);
        renderResolution.minValue = 0;
        renderResolution.maxValue = 3;
        renderResolution.changeValue = 1;
        sub.add(renderResolution);

        sub.add(new PsychOption('Low Quality', 'Reduce graphics for performance', 'lowQuality', BOOL));
        sub.add(new PsychOption('Anti-Aliasing', 'Smoother visuals', 'antialiasing', BOOL));
        sub.add(new PsychOption('dpiScale', 'Scale the game based on your screen\'s DPI', 'useDpiSettings', BOOL));
        sub.add(new PsychOption('Shaders', 'Enable shader effects', 'shaders', BOOL));
        sub.add(new PsychOption('Wide Screen', 'Enable 21:9 widescreen mode', 'wideScreen', BOOL));
        sub.add(new PsychOption('GPU Caching', 'Use GPU for texture caching', 'cacheOnGPU', BOOL));
        sub.add(new PsychOption('Devide Draw And Update', 'Draw and Update in separate threads', 'devideDrawAndUpdate', BOOL));

        var framerate = new PsychOption('Framerate', 'Target framerate', 'framerate', INT);
        framerate.minValue = 60;
        framerate.maxValue = 480;
        framerate.changeValue = 1;
        sub.add(framerate);

        var updaterate = new PsychOption('Update Rate', 'Target update rate', 'updaterate', INT);
        updaterate.minValue = 60;
        updaterate.maxValue = 480;
        updaterate.changeValue = 1;
        sub.add(updaterate);

        sub.add(new PsychOption('Unlimited FPS', 'Remove framerate cap (also for update rate)', 'unlimitedFPS', BOOL));
        sub.add(new PsychOption('FPS Rework', 'Make ur game more smooth', 'fpsRework', BOOL));

        var sub = cat.section('FPSCounter', 'FPS Counter');
        sub.add(new PsychOption('FPS Counter', 'Show FPS counter', 'showFPS', BOOL));
        sub.add(new PsychOption('Show OS', 'Show operating system in FPS Counter', 'showOS', BOOL));
        sub.add(new PsychOption('Show API', 'Show graphics API in FPS Counter', 'showApi', BOOL));
        sub.add(new PsychOption('Show TPS', 'Show ticks per second in FPS Counter', 'showTPS', BOOL));
        sub.add(new PsychOption('Show Memory Peak', 'Show peak memory usage in FPS Counter', 'showMEMPeak', BOOL));

        return cat;
    }
}