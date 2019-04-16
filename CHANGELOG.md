# Syrinx - Sound Manager: Changelog

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