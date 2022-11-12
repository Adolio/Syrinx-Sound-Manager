# Syrinx - Sound Manager: Changelog

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