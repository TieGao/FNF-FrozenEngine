package states.editors.content;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import backend.Song;
import objects.Note;
import moonchart.formats.OsuMania;
import moonchart.formats.fnf.legacy.FNFPsych;
import moonchart.formats.BasicFormat;
import moonchart.formats.BasicFormat.*;
import moonchart.backend.Util;

class OsuConverter
{
    // 从 OSU 转换到 Psych - 对应 "OSU to Psych..." 按钮
    public static function convertOsuToPsych(osuPath:String):SwagSong
    {
        if (!FileSystem.exists(osuPath)) {
            throw 'OSU file does not exist: $osuPath';
        }
        
        try {
            trace('=== Starting OSU to Psych conversion (MoonChart) ===');
            trace('OSU file: $osuPath');
            
            // 1. Use MoonChart to load the OSU file
            var osuChart = new OsuMania().fromFile(osuPath);
            if (osuChart == null) {
                throw 'Failed to load OSU file';
            }
            
            trace('✓ OSU file loaded successfully');
            trace('  Song title: ${osuChart.data.Metadata.Title}');
            trace('  Difficulty: ${osuChart.data.Metadata.Version}');
            trace('  Key count: ${osuChart.data.Difficulty.CircleSize}');
            
            // 2. Create Psych format converter
            var psychChart = new FNFPsych();
            
            // 3. Use MoonChart's fromFormat for automatic conversion
            psychChart.fromFormat(osuChart);
            
            trace('✓ MoonChart conversion successful');
            
            // 4. Get the converted data
            var psychData:Dynamic = psychChart.data;
            
            // 5. Convert to Psych Engine 1.0.4 format
            var swagSong = convertToSwagSong(psychData, osuPath);
            
            trace('=== Conversion Complete ===');
            trace('Song: ${swagSong.song}');
            trace('BPM: ${swagSong.bpm}');
            trace('Sections: ${swagSong.notes.length}');
            
            return swagSong;
            
        } catch (e:Dynamic) {
            trace('Conversion failed: $e');
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            throw 'OSU conversion error: $e';
        }
    }
    
    // 从 Psych 转换到 OSU - 对应 "Psych to OSU..." 按钮
    public static function convertPsychToOsu(psychSong:SwagSong, outputPath:String):Bool
    {
        try {
            trace('=== Starting Psych to OSU conversion ===');
            trace('Output path: $outputPath');
            
            // 1. Convert SwagSong to MoonChart BasicFormat
            var basicChart = convertPsychToBasicChart(psychSong);
            
            // 2. Use MoonChart to create OSU chart
            var osuChart = new OsuMania().fromBasicFormat(basicChart);
            if (osuChart == null) {
                throw 'Failed to create OSU chart from Psych data';
            }
            
            trace('✓ OSU chart created successfully');
            
            // 3. Use MoonChart's stringify to get OSU content
            var osuOutput = osuChart.stringify();
            if (osuOutput == null || osuOutput.data == null) {
                throw 'Failed to stringify OSU chart';
            }
            
            // 4. Save the file
            var dir = haxe.io.Path.directory(outputPath);
            if (dir.length > 0 && !FileSystem.exists(dir)) {
                FileSystem.createDirectory(dir);
            }
            
            File.saveContent(outputPath, osuOutput.data);
            
            trace('✓ OSU file saved to: $outputPath');
            return true;
            
        } catch (e:Dynamic) {
            trace('Psych to OSU conversion failed: $e');
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            return false;
        }
    }
    
    // Convert MoonChart's Psych data to SwagSong format
    static function convertToSwagSong(psychData:Dynamic, osuPath:String):SwagSong
    {
        trace('--- Converting to SwagSong format ---');
        
        // Extract song data from psych format
        var songData:Dynamic = psychData.song;
        
        // Get basic info
        var songName = extractSongName(osuPath);
        var bpm:Float = songData.bpm != null ? songData.bpm : 120.0;
        var speed:Float = songData.speed != null ? songData.speed : 1.0;
        var offset:Float = songData.offset != null ? songData.offset : 0.0;
        
        // Convert sections - FIXED: Check if notes is an array
        var sections:Array<SwagSection> = [];
        var notesData:Dynamic = songData.notes;
        
        if (notesData != null && Std.isOfType(notesData, Array)) {
            var notesArray:Array<Dynamic> = cast notesData;
            
            for (sectionData in notesArray) {
                // Ensure sectionNotes is an array
                var sectionNotes:Array<Dynamic> = [];
                if (sectionData.sectionNotes != null && Std.isOfType(sectionData.sectionNotes, Array)) {
                    sectionNotes = cast sectionData.sectionNotes;
                }
                
                var section:SwagSection = {
                    sectionNotes: sectionNotes,
                    sectionBeats: sectionData.sectionBeats != null ? sectionData.sectionBeats : 4,
                    mustHitSection: sectionData.mustHitSection != null ? sectionData.mustHitSection : true,
                    altAnim: sectionData.altAnim != null ? sectionData.altAnim : false,
                    gfSection: sectionData.gfSection != null ? sectionData.gfSection : false,
                    bpm: sectionData.bpm != null ? sectionData.bpm : bpm,
                    changeBPM: sectionData.changeBPM != null ? sectionData.changeBPM : false
                };
                sections.push(section);
            }
        } else {
            trace('Warning: No notes array found in psych data');
        }
        
        // Convert events - FIXED: Check if events is an array
        var events:Array<Array<Dynamic>> = [];
        var eventsData:Dynamic = songData.events;
        
        if (eventsData != null && Std.isOfType(eventsData, Array)) {
            events = cast eventsData;
        }
        
        // Create the SwagSong object
        var swagSong:SwagSong = {
            song: songName,
            notes: sections,
            events: events,
            bpm: bpm,
            needsVoices: true,
            speed: speed,
            offset: offset,
            
            player1: songData.player1 != null ? songData.player1 : "boyfriend",
            player2: songData.player2 != null ? songData.player2 : "dad",
            gfVersion: songData.gfVersion != null ? songData.gfVersion : "gf",
            stage: songData.stage != null ? songData.stage : "stage",
            format: "psych_v1",
            
            arrowSkin: songData.arrowSkin != null ? songData.arrowSkin : "NOTE_assets",
            splashSkin: songData.splashSkin != null ? songData.splashSkin : "noteSplashes",
            
            gameOverChar: songData.gameOverChar != null ? songData.gameOverChar : "bf-dead",
            gameOverSound: songData.gameOverSound != null ? songData.gameOverSound : "fnf_loss_sfx",
            gameOverLoop: songData.gameOverLoop != null ? songData.gameOverLoop : "gameOver",
            gameOverEnd: songData.gameOverEnd != null ? songData.gameOverEnd : "gameOverEnd",
            
            disableNoteRGB: songData.disableNoteRGB != null ? songData.disableNoteRGB : false
        };
        
        return swagSong;
    }
    
    // Convert SwagSong to MoonChart BasicFormat
    static function convertPsychToBasicChart(psychSong:SwagSong):BasicChart
    {
        trace('--- Converting SwagSong to BasicFormat ---');
        
        // Create BPM changes array
        var bpmChanges:Array<BasicBPMChange> = [{
            time: 0,
            bpm: psychSong.bpm,
            beatsPerMeasure: 4,
            stepsPerBeat: 4
        }];
        
        // Extract BPM changes from events
        if (psychSong.events != null) {
            for (event in psychSong.events) {
                var eventTime:Float = event[0];
                var eventPack:Array<Dynamic> = event[1];
                
                if (eventPack != null) {
                    for (subEvent in eventPack) {
                        if (subEvent[0] == "BPM Change") {
                            var bpm = Std.parseFloat(subEvent[1]);
                            if (!Math.isNaN(bpm)) {
                                bpmChanges.push({
                                    time: eventTime,
                                    bpm: bpm,
                                    beatsPerMeasure: 4,
                                    stepsPerBeat: 4
                                });
                            }
                        }
                    }
                }
            }
        }
        
        // Sort BPM changes by time
        bpmChanges.sort((a, b) -> Std.int(a.time - b.time));
        
        // Create notes array
        var basicNotes:Array<BasicNote> = [];
        var currentTime:Float = 0;
        
        for (section in psychSong.notes) {
            var sectionLength = (60000 / section.bpm) * section.sectionBeats;
            
            for (noteData in section.sectionNotes) {
                var noteTime = currentTime + noteData[0];
                var lane = noteData[1];
                var length = noteData[2];
                var type = noteData.length > 3 ? noteData[3] : "";
                
                basicNotes.push({
                    time: noteTime,
                    lane: lane,
                    length: length,
                    type: type
                });
            }
            
            currentTime += sectionLength;
        }
        
        // Sort notes by time
        basicNotes.sort((a, b) -> Std.int(a.time - b.time));
        
        // Create diffs map
        var diffs = new Map<String, Array<BasicNote>>();
        diffs.set("Converted", basicNotes);
        
        // Create events array
        var basicEvents:Array<BasicEvent> = [];
        if (psychSong.events != null) {
            for (event in psychSong.events) {
                var eventTime:Float = event[0];
                var eventPack:Array<Dynamic> = event[1];
                
                if (eventPack != null) {
                    for (subEvent in eventPack) {
                        if (subEvent[0] != "BPM Change") { // Skip BPM changes as they're handled separately
                            basicEvents.push({
                                time: eventTime,
                                name: subEvent[0],
                                data: {
                                    value1: subEvent[1],
                                    value2: subEvent[2]
                                }
                            });
                        }
                    }
                }
            }
        }
        
        // Calculate key count
        var keyCount = 4;
        for (note in basicNotes) {
            var lane = note.lane;
            if (lane >= 4 && lane < 8) lane -= 4;
            if (lane >= keyCount) keyCount = lane + 1;
        }
        
        // Create extra data map
        var extraData = new Map<String, Dynamic>();
        extraData.set(LANES_LENGTH, keyCount);
        extraData.set(AUDIO_FILE, "audio.mp3");
        extraData.set(SONG_ARTIST, "Unknown");
        extraData.set(SONG_CHARTER, "Unknown");
        
        // Create scroll speeds map
        var scrollSpeeds = new Map<String, Float>();
        scrollSpeeds.set(psychSong.song, psychSong.speed);
        
        trace('Converted ${basicNotes.length} notes, ${basicEvents.length} events');
        trace('Key count: $keyCount');
        
        return {
            data: {
                diffs: diffs,
                events: basicEvents
            },
            meta: {
                title: psychSong.song,
                bpmChanges: bpmChanges,
                scrollSpeeds: scrollSpeeds,
                offset: psychSong.offset,
                extraData: extraData
            }
        };
    }
    
    // Helper function to extract song name from file path
    static function extractSongName(path:String):String
    {
        var fileName = path.split('/').pop().split('\\').pop();
        var name = fileName.substring(0, fileName.lastIndexOf('.'));
        
        // Clean up the filename
        name = ~/[\[\]\(\)\-_]/g.replace(name, ' ');
        name = ~/\s+/g.replace(name, ' ').trim();
        
        // Capitalize first letter of each word
        var words = name.split(' ');
        for (i in 0...words.length) {
            if (words[i].length > 0) {
                words[i] = words[i].charAt(0).toUpperCase() + words[i].substr(1).toLowerCase();
            }
        }
        
        return words.join(' ');
    }
}