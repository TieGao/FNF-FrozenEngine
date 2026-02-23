package states.editors.content;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import backend.Song;
import objects.Note;
import moonchart.formats.fnf.legacy.FNFLegacy;
import moonchart.formats.fnf.legacy.FNFPsych;
import moonchart.formats.BasicFormat;
import moonchart.formats.BasicFormat.*;
import moonchart.backend.Util;

class KadeConverter
{
    // Convert Kade Engine chart to Psych Engine
    public static function convertKadeToPsych(jsonPath:String):SwagSong
    {
        if (!FileSystem.exists(jsonPath)) {
            throw 'Kade Engine file does not exist: $jsonPath';
        }
        
        try {
            trace('=== Starting Kade Engine to Psych conversion (MoonChart) ===');
            trace('Kade file: $jsonPath');
            
            // 1. Use MoonChart to load the Kade Engine file (FNFLegacy format)
            var kadeChart = new FNFLegacy().fromFile(jsonPath);
            if (kadeChart == null) {
                throw 'Failed to load Kade Engine file';
            }
            
            trace('✓ Kade Engine file loaded successfully');
            
            // 2. Create Psych format converter
            var psychChart = new FNFPsych();
            
            // 3. Use MoonChart's fromFormat for automatic conversion
            psychChart.fromFormat(kadeChart);
            
            trace('✓ MoonChart conversion successful');
            
            // 4. Get the converted data
            var psychData:Dynamic = psychChart.data;
            
            // 5. Convert to Psych Engine 1.0.4 format
            var swagSong = convertToSwagSong(psychData, jsonPath);
            
            trace('=== Conversion Complete ===');
            trace('Song: ${swagSong.song}');
            trace('BPM: ${swagSong.bpm}');
            trace('Sections: ${swagSong.notes.length}');
            
            return swagSong;
            
        } catch (e:Dynamic) {
            trace('Kade to Psych conversion failed: $e');
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            throw 'Kade conversion error: $e';
        }
    }
    
    // Convert Psych Engine to Kade Engine
    public static function convertPsychToKade(psychSong:SwagSong, outputPath:String):Bool
    {
        try {
            trace('=== Starting Psych to Kade Engine conversion ===');
            trace('Output path: $outputPath');
            
            // 1. Convert SwagSong to MoonChart BasicFormat
            var basicChart = convertPsychToBasicChart(psychSong);
            
            // 2. Use MoonChart to create Kade Engine chart (FNFLegacy format)
            var kadeChart = new FNFLegacy().fromBasicFormat(basicChart);
            if (kadeChart == null) {
                throw 'Failed to create Kade Engine chart from Psych data';
            }
            
            trace('✓ Kade Engine chart created successfully');
            
            // 3. Use MoonChart's stringify to get JSON content
            var kadeOutput = kadeChart.stringify();
            if (kadeOutput == null || kadeOutput.data == null) {
                throw 'Failed to stringify Kade Engine chart';
            }
            
            // 4. Save the file
            var dir = haxe.io.Path.directory(outputPath);
            if (dir.length > 0 && !FileSystem.exists(dir)) {
                FileSystem.createDirectory(dir);
            }
            
            File.saveContent(outputPath, kadeOutput.data);
            
            trace('✓ Kade Engine file saved to: $outputPath');
            return true;
            
        } catch (e:Dynamic) {
            trace('Psych to Kade conversion failed: $e');
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            return false;
        }
    }
    
    // Convert MoonChart's Psych data to SwagSong format
    static function convertToSwagSong(psychData:Dynamic, sourcePath:String):SwagSong
    {
        trace('--- Converting to SwagSong format ---');
        
        var songData:Dynamic = psychData.song;
        var songName = extractSongName(sourcePath);
        var bpm:Float = songData.bpm != null ? songData.bpm : 120.0;
        var speed:Float = songData.speed != null ? songData.speed : 1.0;
        var offset:Float = songData.offset != null ? songData.offset : 0.0;
        
        // Convert sections
        var sections:Array<SwagSection> = [];
        var notesData:Dynamic = songData.notes;
        
        if (notesData != null && Std.isOfType(notesData, Array)) {
            var notesArray:Array<Dynamic> = cast notesData;
            
            for (sectionData in notesArray) {
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
        }
        
        // Convert events
        var events:Array<Array<Dynamic>> = [];
        var eventsData:Dynamic = songData.events;
        
        if (eventsData != null && Std.isOfType(eventsData, Array)) {
            events = cast eventsData;
        }
        
        // Create SwagSong object
        var swagSong:SwagSong = {
            song: songName,
            notes: sections,
            events: events,
            bpm: bpm,
            needsVoices: true,
            speed: speed,
            offset: offset,
            
            player1: songData.player1 != null ? songData.player1 : "bf",
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
                        if (subEvent[0] != "BPM Change") {
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
    
    static function extractSongName(path:String):String
    {
        var fileName = path.split('/').pop().split('\\').pop();
        var name = fileName.substring(0, fileName.lastIndexOf('.'));
        
        name = ~/[\[\]\(\)\-_]/g.replace(name, ' ');
        name = ~/\s+/g.replace(name, ' ').trim();
        
        var words = name.split(' ');
        for (i in 0...words.length) {
            if (words[i].length > 0) {
                words[i] = words[i].charAt(0).toUpperCase() + words[i].substr(1).toLowerCase();
            }
        }
        
        return words.join(' ');
    }
}