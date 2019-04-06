# Syrinx - Sound Manager for Adobe AIR

by Aurélien Da Campo ([Adolio](https://twitter.com/AurelienDaCampo))

## ⭐ Key features

- MP3 & WAV formats support
- Tracks registration / configuration management
- Intuitive & friendly API
- Seamless sound looping via silence trimming and/or WAV files format
- Pitch capability

## ▶️ Try it!

Go to the [demo](./demo/) folder, configure the project & run it or if you get the latest [release](https://github.com/Adolio/AS3-Sound-Manager/releases), the demo binary should by available in the archive.

## 📄 Full features

- **Sound Manager**
	- Tracks registration management
		- Register / unregister track
		- Get all registered tracks
		- Has registered track?
	- **Track configuration**
		- Type
		- Sampling rate
		- Trimming (start / end)
			- Automatic trimming detection
	- Sound instantiation from registered tracks
		- Play sound (returns a *Sound Instance*)
			- Starting volume
			- Starting position
			- Loop & infinite looping
			- Starting paused
	- Sound format modularity
		- Supported formats:
			- MP3
			- WAV
	- Sound instances management
		- Master volume
		- Get all sound instances
		- Get all sound instances by type
		- Stop all sound instances
		- Destroy all sound instances
	- Events
		- Track registered
		- Track unregistered
		- Sound instance added
		- Sound instance removed
- **Sound Instance**
	- Controls
		- Execution (play / pause / resume / stop)
		- Volume
		- Position (time & ratio)
		- Mute
		- Pan
		- Pitch
	- Status & configuration
		- Length
		- Total length (incl. loops)
		- Volume / Mixed volume
		- Is muted?
		- Pan
		- Pitch
		- Loops / remaining loops
		- Position (time & ratio)
		- Is playing?
		- Is started?
		- Is paused?
		- Is destroyed?
	- Events
		- Started
		- Paused
		- Resumed
		- Stopped
		- Completed
		- Destroyed

## ⌨️ How to use?

### 📻 Sound Manager

Main class to register tracks & instantiate sounds. The following example registers two tracks (MP3 & Wav), setups the trimming & sampling options.
Then three sounds are instantiated.

```actionscript
// Embedded sounds (Note that WAV files requires a mime type)
[Embed(source = "../media/sound/engine.mp3")] public static const EngineSoundMp3:Class;
[Embed(source = "../media/sound/engine.wav", mimeType="application/octet-stream")] public static const EngineSoundWav:Class;

private var _soundManager:SoundManager;

public function SoundManagerExample()
{
	// Create Sound Manager
	_soundManager = new SoundManager();

	// Register sounds
	var engineSoundMp3Config:TrackConfiguration = _soundManager.registerTrack("Engine 1", new Mp3Track(new EngineSoundMp3())); // Register a MP3 track
	var engineSoundWavConfig:TrackConfiguration = _soundManager.registerTrack("Engine 2", new WavTrack(new EngineSoundWav())); // Register a WAV track

	// Trimming configuration
	engineSoundMp3Config.findTrim(0.01); // Find start & end trim durations to remove silences inherent to mp3 format (with a silent threshold of 0.01)

	// Sampling rate configuration
	engineSoundWavConfig.sampling = 4096; // This defines how much samples are read per sampling request. The value must be between 2048 (included) and 8192 (included).

	// Play sounds
	var engine1_once:SoundInstance = _soundManager.play("Engine 1", 1.0); // Play once
	var engine1_twice:SoundInstance = _soundManager.play("Engine 1", 1.0, 0, 1); // Play twice (repeat once)
	var engine2_infinite:SoundInstance = _soundManager.play("Engine 2", 1.0, 0, -1); // Play infinite

	// Control master volume
	_soundManager.volume = 0.8;
}
```

### 🎵 Sound Instance

Instance of a sound that can be controlled. The following example shows how to listen to sound events, how to control a sound and how to get various information about it.

```actionscript
var si:SoundInstance = _soundManager.play("Engine 1", 1.0, 1337, 5); // Play at max volume, starting at 1,337 sec., 6 times (looping 5 times)

//-----------------------------------------------------------------------------
//-- Events
//-----------------------------------------------------------------------------

si.started.add(function (si:SoundInstance):void { trace("Sound started. " + si.type); } );
si.stopped.add(function (si:SoundInstance):void { trace("Sound stopped. " + si.type); } );
si.paused.add(function (si:SoundInstance):void { trace("Sound paused. " + si.type); } );
si.resumed.add(function (si:SoundInstance):void { trace("Sound resumed. " + si.type); } );
si.completed.add(function (si:SoundInstance):void { trace("Sound completed. " + si.type); } );
si.destroyed.add(function (si:SoundInstance):void { trace("Sound destroyed. " + si.type); } );

//-----------------------------------------------------------------------------
//-- Controls
//-----------------------------------------------------------------------------

// Execution controls
si.pause();
si.resume();
si.stop();
si.play(0.5, 0, 1.0); // (Re)play twice (repeat once)

// Position
si.position = 1337; // In milliseconds
si.positionRatio = 0.5; // This includes the loops so here it will play only the second loop!

// Mute
si.isMuted = true;
si.isMuted = false;

// Volume
si.volume = 0;
si.volume = 0.8;

// Pan
si.pan = -0.5; // Half left

// Pitch
si.pitch = 0.8; // 20% slower
si.pitch = 1.2; // 20% faster
si.pitch = 1.0; // Back to default

//-----------------------------------------------------------------------------
//-- Status info
//-----------------------------------------------------------------------------
trace("Type: " + si.type); // Type
trace("Volume: " + si.volume); // Volume
trace("Mixed volume: " + si.mixedVolume); // Equals to _soundManager.volume * volume
trace("Pan: " + si.pan); // Pan
trace("Pitch: " + si.pitch); // Pitch
trace("Sound length: " + si.length); // One loop length in milliseconds (trimmed)
trace("Sound total length: " + si.totalLength); // Total length in milliseconds (including loops & trim durations)
trace("Loops: " + si.loops); // Total loops
trace("Remaining loops: " + si.loopsRemaining); // Remaining loops
trace("Current position: " + si.position); // Current position in milliseconds
trace("Current position (ratio): " + si.positionRatio); // Current position (ratio, between 0..1)
trace("Is started: " + si.isStarted); // Is started?
trace("Is playing: " + si.isPlaying); // Is playing?
trace("Is paused: " + si.isPaused); // Is paused?
trace("Is muted: " + si.isMuted); // Is muted?
trace("Is destroyed: " + si.isDestroyed); // Is destroyed?
```

### 💡 Recommendations

- Wav file format is recommended for seamless looping sound since MP3 format introduces silent parts at the beginning & the end of the track.
	- Another option could be to use MP3 & configure trimming durations either manually or by using the `TrackConfiguration.findTrim()` utility method.
- Use higher sampling rate for tracks that require more robustness against frame drop (e.g. during loading).

## 📦 How to install?

- Checkout this repository & add `src` folder in your `classpath` or copy paste the content of the `src` folder in your source folder.

or

- Use the `.swc` file provided in each release.

Don't forget to include dependencies (see below).

## ☝️ Limitations

- Supported Wav formats:
	- PCM 16 bits, 1 channel, 44100 Hz
	- PCM 16 bits, 2 channels, 44100 Hz
	- IEEE Float 32 bits, 1 channel, 44100 Hz
	- IEEE Float 32 bits, 2 channels, 44100 Hz

## 🔗 Minimum Requirements

- Adobe AIR 32.0 in order to fix crackling artifacts: https://github.com/Gamua/Adobe-Runtime-Support/issues/46

## 🖇 Dependencies (included in `libs` folder)

- AS3 Signals: https://github.com/robertpenner/as3-signals