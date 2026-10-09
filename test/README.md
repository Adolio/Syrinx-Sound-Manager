# Test Project

Automated tests of the library (`src`), run through `adl` without showing a window.

The test framework lives in `src/ch/adolio/test` and stays independent of the library. The tests of the library live
in `src/ch/adolio/sound/test`, where they are registered in `TestMain.as`, either as synchronous (`ITest`) or
asynchronous (`ITestAsync`) tests. When adding, removing or extending a test, update the coverage below.

## Running

From the repository root, with `<air-sdk-path>` the path of an AIR SDK (33.1 or later, tested with 33.1 & 51.4):

```powershell
npx --yes asconfigc --sdk <air-sdk-path> --project test/asconfig.json --debug=true
& "<air-sdk-path>/bin/adl.exe" test/bin/application.xml test/bin
```

The run prints `All N test(s) passed.` and exits with code 0, or 1 when a test fails. Build in debug mode
(`--debug=true`): the stack traces of failures then give the file & line of the failed assertion.

The playback tests need a sound output device to acquire sound channels. Sounds are played at a master volume of 0,
so the run is silent. An asynchronous test which does not report its result within 10 seconds fails. A run which
never ends reveals a freeze of the application, which no timeout can report.

`PositionTestAsync` compares positions with the elapsed time: it may fail on a machine too busy to play sounds in
real time.

## Writing Tests

- Prefer `ProbeTrack` over audio files: a synthetic track of generated samples (tone, silences or any function), whose
  length is known to the sample & which records its extractions
- The samples written by a playing sound cannot be read back: check what the sound reads from its `ProbeTrack` instead
  (extractions count, positions between two samples, lowest & highest samples)
- Build WAVE files with `WavBuilder` to test the parsing of a given format
- Set the master volume of the managers playing sounds to 0
- Extend `ScenariosTestAsync` for an asynchronous test made of several scenarios: it runs them one after the other &
  fails the test on any error raised through `attempt` or `defer`
- `SoundInstancesPool.instance` is shared by all the tests: use track types unique to the scenario & compare the pool
  statistics with their values at the start of the scenario
- Check the effects of a signal after its dispatch is over (see `defer` in `ScenariosTestAsync`): the Sound Manager
  reacts to the signals of its instances before the listeners of the test

## Coverage

| Test | Covered behavior |
|------|------------------|
| `WavTrackTest` | Length & extracted samples of the supported formats (PCM 16 bits & IEEE float 32 bits, mono & stereo), with & without pre-decoding, extraction from a position, from a position between two samples & near the end, unknown chunk skipped, rejection of other sample rates, bit depths, channel counts & audio formats |
| `TrackConfigurationTest` | Defaults, sampling bounds, trims exceeding the length rejected, start & end trims detection exact to the sample (silences not aligned on the sampling, shorter than the sampling, below the threshold, isolated sample after a silence, max sampling, start position), automatic trims, `findTrim` (including a fully silent track), silent tracks without stack overflow (two blocks & 30 seconds), cloning (except the base volume), time to samples conversions, destruction |
| `TrackRegistrationTest` | Registration & its signal, lookups, duplicate type rejected, automatic start trim at registration, unregistration & its signal (configuration destroyed, track kept), unregistered type played, max channel capacity |
| `SoundInstanceTest` | Instances not played: registration to the manager & lookups, initial status, trimmed length, volume, base volume & mixed volume (with clamping), pan & mute, position & position ratio before start (with rejection of invalid values), manager change, destruction & destruction of all instances, null configuration rejected |
| `PoolTest` | Acquisition, release (signals, stop, listeners cleared), recycling of the same type (pan, mute, pitch, volume, loops & free when completed reset), recycled instance following the trims changed meanwhile, other type not recycled, release of all instances, null & destroyed instances rejected, release refused while pooling is disabled |
| `PlaybackTest` | Play, pause, resume & stop with their signals (custom sampled sound), loops & infinite looping setup, start from a later loop, remaining time from a later loop, negative start time rejected, position changes while playing & paused, stop all (including listeners freeing instances meanwhile), completed listeners called before the instance is freed, standard MP3 sound (position change, pause & resume), sounds without length (fully trimmed or empty track) completed when played, with or without loops |
| `ChannelCapacityTest` | Max channel capacity reached: sounds with a finite number of loops skipped (completed, destroyed, kept alive or released to the pool) without piling up in the manager, infinitely looping sound put on hold at its start position, resumed only once a channel is available, paused finite sound skipped when resumed without channel |
| `CompletionTestAsync` (async) | Completion destroying the instance, completed listeners called before the destruction or the release to the pool, instance played again by a completed listener kept, loops played before completion, instance kept alive (`freeWhenCompleted` disabled) no longer playing nor started & positioned at its end, completion releasing the instance to the pool, track ending on a sampling boundary completed once, looping track giving no sample completed |
| `PitchTestAsync` (async) | Track read from whole sample positions only, while pitched & after the pitch is reset to its default, looping trimmed track read from its start trim up to its end trim only, with a pitch above & below the default |
| `PositionTestAsync` (async) | Position of playing custom sampled sounds following what is heard: sound started from a later loop, samples fed far ahead of the playback (max sampling), pitched sound, position continuous when the pitch is set & reset on a looping sound, remaining time, pause keeping the loop heard |

When fixing a bug, add a test reproducing it first.

## Expected Logs

`[Track Configuration] Impossible to find correct trimming durations. Sound is fully silent with silent threshold of 0.6.`
is expected: `TrackConfigurationTest` runs `findTrim` on a track made silent by its threshold.

`[Sound Instance] Impossible to acquire a sound channel for sound '...'.` logs are expected: `ChannelCapacityTest`
plays sounds beyond the max channel capacity of their manager.
