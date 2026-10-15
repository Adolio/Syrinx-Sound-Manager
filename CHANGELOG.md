# Syrinx - Sound Manager: Changelog

## v0.7 (2026-10-15)

- Sound Manager: Added a `destroy` method & an `isDestroyed` accessor, to free the sound instances, unregister the tracks & stop counting the max channel capacity
- Sound Manager: Added a `totalMaxChannelCapacity` static accessor & a warning when the max channel capacities of all the managers exceed the `MAX_CHANNELS` of Adobe AIR
- Sound Manager: Made the registration reject null tracks & null or empty types with an `ArgumentError`
- Sound Manager: Made the volume clamped between `VOLUME_MIN` & `VOLUME_MAX`
- Sound Manager: Fixed `stopAll` skipping sounds when a completion listener frees sounds
- Sound Manager: Fixed sounds played again from their completion listener being freed
- Sound Manager: Fixed completion of pooled sounds raising an error once pooling is disabled
- Sound Instance: Changed sounds with a finite number of loops to be skipped (completed right away) when no sound channel is available, instead of being put on hold forever
- Sound Instance: Changed `positionRatio` of infinitely looping sounds to apply within the current loop
- Sound Instance: Made an invalid start time, position or pitch (including values which are not a number) raise an `ArgumentError`, and the volumes which are not a number be considered as max
- Sound Instance: Made sounds without length complete when played
- Sound Instance: Made setting the same manager again ignored
- Sound Instance: Fixed start position & `resumed` signal of infinitely looping sounds put on hold when no sound channel is available
- Sound Instance: Fixed recycled sound instances keeping the fields, sampling bounds & options of their previous use
- Sound Instance: Fixed the state of completed sounds
- Sound Instance: Fixed the position of custom sampled sounds across loops, pitch changes & pauses, and the remaining time
- Sound Instance: Fixed current loop & loops remaining running ahead of the sound heard & being inconsistent once completed
- Sound Instance: Fixed pitched sounds reading beyond the end trim & past the extracted samples
- Sound Instance: Fixed misaligned WAV data read after resetting the pitch to its default
- Sound Instance: Fixed fractional trim durations being truncated & sample positions falling one sample short
- Sound Instance: Fixed the freeze of looping sounds without samples
- Sound Instance: Removed the `EventDispatcher` base class, which never dispatched any event (breaking: a `Sound Instance` is no longer an `EventDispatcher`; use its signals)
- Sound Instance: Removed the safe channel acquisition option, which could not be disabled
- Sound Instances Pool: Added an `availableCount` accessor & deprecated `capacity`, which returns the same value
- Sound Instances Pool: Made `releaseSound` return whether the sound was released
- Sound Instances Pool: Fixed instances released twice, recycled for another track or kept after their track unregistration or their destruction
- Sound Instances Pool: Fixed errors raised without the `new` keyword
- Track Configuration: Made the constructor reject null tracks & null or empty types, and the trims reject values which are not a number, with an `ArgumentError`
- Track Configuration: Fixed end trim detection & the stack overflow of trims detection on silent tracks
- Track Configuration: Fixed `clone` dropping the base volume
- Wav Track: Made invalid files raise an `IllegalOperationError` describing the issue, and null data an `ArgumentError`
- Wav Track: Fixed parsing of format chunks with an extension & of chunks of odd size, and the hang on a corrupted chunk size
- Wav Track: Made `extractPreDecoded` private, an implementation detail of `extract` (breaking)
- Mp3 Track: Made the constructor reject null sounds with an `ArgumentError`
- Demo: Upgraded Starling to version 2.8 & Feathers UI to version 4.1.1
- Demo: Fixed errors on invalid start position, trims & loaded files
- Demo: Fixed entries of sounds released to the pool being kept refreshed & never disposed
- Demo: Fixed the initial master volume not being applied & the running sounds list layout
- Demo: Replaced the PCM 16 bits mono sound, which was an IEEE float 32 bits file, by a real one
- Demo: Removed the packaging configuration, releases no longer including the demo binary
- Tests: Added a test project
- Documentation: Corrected the README & documented the lifecycle of tracks, configurations & sounds, the build of the projects, the supported AIR SDK versions & the licences of the third-party content

## v0.6 (2022-11-12)

- Sound Manager: Added `Sound Instance` pooling capability
- Sound Manager: Fixed typo in `getRegisteredTracks` method
- Demo: Updated to support the new pooling capability
- Demo: Fixed viewport
- Demo: Improved events handling

## v0.5 (2022-07-26)

- Track Configuration: Added base volume for volume mastering configuration
- Sound Instance: Added base volume for volume mastering
- Sound Manager: Added `findRegisteredTrack` method
- Sound Instance: Fixed minor constant usage

## v0.4 (2022-01-11)

- Sound Instance: Fixed looping capability for standard sounds
- Sound Instance: Added `currentLoop` accessor
- Demo: Extended loops limit
- Demo: Improved stop & re-play capability

## v0.3 (2020-09-30)

- Sound Instance: Added remaining time method
- Sound Manager: Fixed destroy all sound instances method
- Track Configuration: Fixed missing parameter type

## v0.2 (2019-04-16)

- Sound Instance: Improved performance for native MP3 sounds
- Sound Instance: Added safe channel acquisition option
- Sound Manager: Added max channel capacity capability
- Sound Manager: Added getter for playing sound instances count
- Sound Manager: Added optional automatic trimming durations detection at track registration
- Demo: Fixed WAV file loading cancellation
- Demo: Updated to show actually playing sound instances over registered sound instances

## v0.1 (2019-04-05)

- Initial version of the library
- Added WAV format support (PCM 16bit & IEEE 32bit, mono/stereo, 44100 Hz)
- Added full sound management capability (see feature list in README.md)
- Added custom sampling capability
- Added trimming capability
- Added pitch capability