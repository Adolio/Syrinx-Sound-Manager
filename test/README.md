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
so the run is silent. An asynchronous test which does not report its result within 10 seconds fails.

## Writing Tests

- Prefer `ProbeTrack` over audio files: a synthetic track of generated samples (tone, silences or any function), whose
  length is known to the sample & which records its extractions
- Build WAVE files with `WavBuilder` to test the parsing of a given format
- Set the master volume of the managers playing sounds to 0
- `SoundInstancesPool.instance` is shared by all the tests: use track types unique to the scenario & compare the pool
  statistics with their values at the start of the scenario
- Check the effects of a signal after its dispatch is over (see `defer` in `CompletionTestAsync`): the Sound Manager
  reacts to the signals of its instances before the listeners of the test

## Coverage

| Test | Covered behavior |
|------|------------------|
| `WavTrackTest` | Length & extracted samples of the supported formats (PCM 16 bits & IEEE float 32 bits, mono & stereo), with & without pre-decoding, extraction from a position & near the end, unknown chunk skipped, rejection of other sample rates, bit depths, channel counts & audio formats |
| `TrackConfigurationTest` | Defaults, sampling bounds, trims exceeding the length rejected, start trim detection (leading silence, none, samples below the threshold) & automatic start trim, cloning (except the base volume), time to samples conversions, destruction |
| `TrackRegistrationTest` | Registration & its signal, lookups, duplicate type rejected, automatic start trim at registration, unregistration & its signal (configuration destroyed, track kept), unregistered type played, max channel capacity |
| `SoundInstanceTest` | Instances not played: registration to the manager & lookups, initial status, trimmed length, volume, base volume & mixed volume (with clamping), pan & mute, position & position ratio before start (with rejection of invalid values), manager change, destruction & destruction of all instances, null configuration rejected |
| `PoolTest` | Acquisition, release (signals, stop, listeners cleared), recycling of the same type (pan, mute & pitch reset), other type not recycled, release of all instances, null & destroyed instances rejected, release refused while pooling is disabled |
| `PlaybackTest` | Play, pause, resume & stop with their signals (custom sampled sound), loops & infinite looping setup, start from a later loop, negative start time rejected, position changes while playing & paused, stop all, standard MP3 sound (position change, pause & resume) |
| `CompletionTestAsync` (async) | Completion destroying the instance, loops played before completion, instance kept alive (`freeWhenCompleted` disabled), completion releasing the instance to the pool |

When fixing a bug, add a test reproducing it first.
