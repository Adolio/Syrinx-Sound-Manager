# Syrinx - Sound Manager for Adobe AIR

by Aurélien Da Campo ([Adolio](https://twitter.com/AurelienDaCampo))

## ⭐ Key features

- MP3 & WAV formats support
- Tracks registration / configuration management
- Intuitive & friendly API
- Seamless sound looping via silence trimming and/or WAV files format
- Pitch capability
- Sound instances pooling

## ▶️ Try it!

Go to the [demo](./demo/) folder, configure the project & run it.

## 📄 Full features

- **Sound Manager**
	- Tracks registration management
		- Register / unregister track
		- Get all registered tracks
		- Has registered track?
	- **Track configuration**
		- Type
		- Base volume (for mastering)
		- Sampling (samples fed per sampling request)
		- Trimming (start / end)
			- Automatic trimming detection
	- Sound instantiation from registered tracks
		- Play sound (returns a *Sound Instance*)
			- Starting volume
			- Starting position
			- Loop & infinite looping
	- Sound format modularity
		- Supported formats:
			- MP3
			- WAV
	- Sound instances management
		- Master & base volume
		- Get all sound instances
		- Get all sound instances by type
		- Stop all sound instances
		- Destroy all sound instances
		- Max channel capacity
	- Destruction (frees its sound instances & unregisters its tracks)
	- Events
		- Track registered
		- Track unregistered
		- Sound instance added
		- Sound instance removed
		- Sound instance released to pool
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
		- Volume / Base volume / Mixed volume
		- Is muted?
		- Pan
		- Pitch
		- Loops / current loop / remaining loops
		- Position (time & ratio)
		- Remaining time
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

Main class to register tracks & instantiate sounds. The following example registers two tracks (MP3 & Wav), sets up the trimming & sampling options.
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
	_soundManager.maxChannelCapacity = 8; // Limit number of simultaneous playing sounds (for this sound manager only)
	_soundManager.isPoolingEnabled = true; // Enable pooling to reuse already instantiated sounds and reduce GC impacts

	// Register sounds
	var engineSoundMp3Config:TrackConfiguration = _soundManager.registerTrack("Engine 1", new Mp3Track(new EngineSoundMp3())); // Register a MP3 track
	var engineSoundWavConfig:TrackConfiguration = _soundManager.registerTrack("Engine 2", new WavTrack(new EngineSoundWav())); // Register a WAV track

	// Trimming configuration
	engineSoundMp3Config.findTrim(0.01); // Find start & end trim durations to remove silences inherent to mp3 format (with a silent threshold of 0.01)

	// Sampling configuration
	engineSoundWavConfig.sampling = 4096; // This defines how many samples are read per sampling request. The value must be between 2048 (included) and 8192 (included).

	// Base volume configuration for mastering
	engineSoundMp3Config.baseVolume = 0.5; // Custom mastering at track configuration level, the sound can now be played at 1.0 but will still be influenced by this mastering.

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
var si:SoundInstance = _soundManager.play("Engine 1", 1.0, 1337, 5); // Play at max volume, starting at 1337 ms, 6 times (looping 5 times)

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
si.play(0.5, 0, 1); // (Re)play twice (repeat once)

// Position
si.position = 1337; // In milliseconds
si.positionRatio = 0.5; // Loops included: with 6 plays, 0.5 is the start of the fourth one

// Mute
si.isMuted = true;
si.isMuted = false;

// Volume
si.volume = 0;
si.volume = 0.8;

// Pan
si.pan = -0.5; // Half left

// Pitch
si.pitch = 0.8; // 20% slower & lower
si.pitch = 1.2; // 20% faster & higher
si.pitch = 1.0; // Back to default

//-----------------------------------------------------------------------------
//-- Status info
//-----------------------------------------------------------------------------
trace("Type: " + si.type); // Type
trace("Volume: " + si.volume); // Volume
trace("Mixed volume: " + si.mixedVolume); // Equals to _soundManager.volume * si.baseVolume * si.volume
trace("Pan: " + si.pan); // Pan
trace("Pitch: " + si.pitch); // Pitch
trace("Sound length: " + si.length); // One loop length in milliseconds (trimmed)
trace("Sound total length: " + si.totalLength); // Total length in milliseconds (trimmed, loops included)
trace("Loops: " + si.loops); // Total loops
trace("Current loop: " + si.currentLoop); // Loop being heard (0 = first play, 1 = second play, etc.)
trace("Remaining loops: " + si.loopsRemaining); // Remaining loops (-1 = infinite)
trace("Remaining time: " + si.remainingTime); // Remaining time in milliseconds
trace("Current position: " + si.position); // Current position in milliseconds
trace("Current position (ratio): " + si.positionRatio); // Current position (ratio, between 0..1)
trace("Is started: " + si.isStarted); // Is started?
trace("Is playing: " + si.isPlaying); // Is playing?
trace("Is paused: " + si.isPaused); // Is paused?
trace("Is muted: " + si.isMuted); // Is muted?
trace("Is destroyed: " + si.isDestroyed); // Is destroyed?
```

### ♻️ Sound Instances Pooling

Pooling reuses already instantiated `Sound Instances` instead of creating new ones. This reduces allocations & therefore the lags caused by the `Garbage Collector` passage, at the cost of keeping the released instances in memory. Therefore this capability could be pretty useful when playing a lot of identical sounds in your application (e.g. player footsteps, arrows thrown by an army of archers, etc.).

The pooling capability can be enabled this way:

```actionscript
_soundManager.isPoolingEnabled = true;
```

**Important**: When a `Sound Instance` is completed, it will automatically be returned to the pool. Beware of not keeping references to completed  `Sound Instances` because they might soon be re-used somewhere else.

Infinite looping sounds (e.g. seamless looping sounds) can be manually returned to the pool by calling the following method:

```actionscript
_soundManager.releaseSoundInstanceToPool(mySound);
```

**Important**: Release `Sound Instances` instead of destroying them when the pooling capability is active. A destroyed `Sound Instance` is never recycled.

Releasing a `Sound Instance` which is already in the pool is ignored.

### 🧹 Lifecycle

- **Tracks** belong to the application: the library never destroys them. Unregistering a track, or destroying its `Sound Manager`, destroys its `Track Configuration` only. Call `destroy()` on a track once no `Sound Manager` uses it anymore.
- **Unregistering a track** doesn't stop its sounds: the ones playing keep playing until they end, while the ones waiting in the pool are destroyed. A pooled sound still playing goes back to the pool when it ends & keeps the track there.
- **MP3 tracks** must wrap a fully loaded `Sound`: trimmed or pitched sounds & automatic trims use the length of the sound at the time they are created, which is incomplete while it loads.
- **WAV data** given to a `WavTrack` must not be modified afterwards, unless the track is pre-decoded: the track keeps reading its samples from it.
- **Destroyed objects** must not be used anymore: a destroyed `Sound Manager` or `Sound Instance`, or the `Track Configuration` of an unregistered track. Nor a `Sound Instance` released to the pool, which may already be playing for someone else.

### 🚦 Sound channels limit

Adobe AIR plays at most 32 sounds at the same time, all `Sound Managers` together. A `Sound Manager` can be limited further with `maxChannelCapacity`, which is 32 by default.

When using several `Sound Managers`, give each one its share of the 32 channels, so that the sounds of one can never take the channels another one relies on:

```actionscript
_musicSoundManager.maxChannelCapacity = 4;
_uiSoundManager.maxChannelCapacity = 4;
_fxSoundManager.maxChannelCapacity = 24;
```

A warning is traced when the capacities of the `Sound Managers` add up to more than 32. `SoundManager.totalMaxChannelCapacity` returns their sum.

A `Sound Manager` which is no longer needed must be destroyed, so that its capacity is no longer counted:

```actionscript
_soundManager.destroy(); // Frees its sound instances & unregisters its tracks
```

When a sound cannot get a sound channel:

- A sound with a finite number of loops is skipped: it completes right away, as if it had been played until its end.
- An infinitely looping sound is put on hold: it is paused at its start position & stays in its `Sound Manager`. Call `resume()` to try again; it stays paused as long as no sound channel is available.

### 💡 Recommendations

- A `Track Configuration` is read when a `Sound Instance` is created: changing its base volume, trims or sampling afterwards only applies to the sounds played afterwards. To change the base volume of a sound already playing, set the `baseVolume` of its `Sound Instance`.
- Standard sounds (MP3 Tracks without trimming nor pitching options set) are treated as normal flash sound (no custom data sampling required) which provides better overall performance over advanced sounds processing. Sampling is therefore ignored for those sounds.
- Wav file format is recommended for seamless looping sound since MP3 format introduces silent parts at the beginning & the end of the track.
	- Another option could be to use MP3 & configure trimming durations either manually or by using the `TrackConfiguration.findTrim()` utility method.
- The sampling is the number of samples fed per sampling request, from 2048 to 8192 (about 46 to 186 ms of sound). Use a higher sampling for tracks that require more robustness against frame drop (e.g. during loading): more sound is fed ahead, so pitch changes are heard later.

## 📦 How to install?

- Checkout this repository & add `src` folder in your `classpath` or copy paste the content of the `src` folder in your source folder.

or

- Use the `.swc` file provided in each release.

Don't forget to include dependencies (see below).

## 🔨 How to build?

The project is set up for Visual Studio Code with the ActionScript & MXML extension.

The AIR SDK path set in the `.vscode/settings.json` files (root, `demo` & `test`) is the one of the author: change `as3mxml.sdk.framework` to your own AIR SDK path locally, without committing it.

The projects can also be built from a terminal, from the repository root:

```powershell
npx --yes asconfigc --sdk <air-sdk-path> --project asconfig.json       # library (SWC)
npx --yes asconfigc --sdk <air-sdk-path> --project demo/asconfig.json  # demo
```

## 🧪 Tests

The `test` folder holds the automated tests of the library. See [test/README.md](test/README.md) to build & run them.

## ☝️ Limitations

- Supported Wav formats:
	- PCM 16 bits, 1 channel, 44100 Hz
	- PCM 16 bits, 2 channels, 44100 Hz
	- IEEE Float 32 bits, 1 channel, 44100 Hz
	- IEEE Float 32 bits, 2 channels, 44100 Hz

## 🔗 Minimum Requirements

- AIR SDK 33.1 or later (tested with 33.1 & 51.4)
- Adobe AIR 32.0 fixed crackling artifacts of custom sampled sounds: https://github.com/Gamua/Adobe-Runtime-Support/issues/46

## 🖇 Dependencies (included in `libs` folder)

- AS3 Signals: https://github.com/robertpenner/as3-signals