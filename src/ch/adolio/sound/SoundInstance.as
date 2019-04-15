// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio.sound
{
	import flash.errors.IllegalOperationError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.SampleDataEvent;
	import flash.media.SoundChannel;
	import flash.media.SoundTransform;
	import flash.utils.ByteArray;
	import org.osflash.signals.Signal;
	import flash.utils.getTimer;
	
	/**
	 * An instance of a sound.
	 *
	 * @author Aurelien Da Campo
	 */
	public class SoundInstance extends EventDispatcher
	{
		// Const
		public static const VOLUME_MIN:Number = 0;
		public static const VOLUME_MAX:Number = 1.0;
		public static const PITCH_DEFAULT:Number = 1.0;
		private static const SAMPLE_RATE_MS:Number = 44.1; // Frequency per millisecond

		// Core
		private var _manager:SoundManager;
		private var _type:String;
		private var _track:Track;
		private var _channel:SoundChannel;
		private static var safeChannelAquisition:Boolean = true; // If false, an error will be raised on channel acquisition failure (play, resume, position set, etc.)
		private var _soundTransform:SoundTransform;
		private var _isStandardSound:Boolean; // Standard sound without any special effect such as trimming or pitching
		private var _standardSoundLoopPosition:Number = 0; // Used to keep track of the actual current position when looping
		
		// Options
		private var _soundConfig:TrackConfiguration;
		private var _startTime:Number;
		private var _infiniteLooping:Boolean = false;
		private var _loops:int = 0;
		private var _isMuted:Boolean = false;
		private var _volume:Number = VOLUME_MAX; // instance volume, not mixed
		private var _pitch:Number = PITCH_DEFAULT;
		private var _destroyOnComplete:Boolean = true;
		
		// Triming
		private var _trimStartDuration:int = 0; // In milliseconds
		private var _trimEndDuration:int = 0; // In milliseconds
		
		// Custom sampling
		private var _extractionFunc:Function;
		private var _fakeSound:flash.media.Sound;
		private var _readingTipPos:Number = 0; // The diamond position, in samples
		private var _readLoopsRemaining:int = 0; // Internal read loops. DO NOT USE out of data sampling
		private var _samplingCount:uint = 0;
		private var _startPosition:uint; // In samples
		private var _endPosition:uint; // In samples
		private var _pitchExtractedData:ByteArray = new ByteArray();
		private var _pitchStartPosition:Number = 0; // Position where the pitching started
		private var _pitchStartTimer:int = 0; // Used to track past time in pitching mode, in milliseconds
		
		// Status
		private var _isStarted:Boolean = false;
		private var _pauseTime:Number = 0; // In milliseconds
		private var _isPaused:Boolean = false;
		private var _isDestroyed:Boolean = false;
		
		// Signals
		public var started:Signal = new Signal(SoundInstance); // Dispatched when the sound is started (it happens only once)
		public var paused:Signal = new Signal(SoundInstance); // Dispatched when the sound is paused
		public var resumed:Signal = new Signal(SoundInstance); // Dispatched when the sound is resumed after pause
		public var stopped:Signal = new Signal(SoundInstance); // Dispatched when the sound is stopped
		public var completed:Signal = new Signal(SoundInstance); // Dispatched when the sound is completed
		public var destroyed:Signal = new Signal(SoundInstance); // Dispatched when the sound is destroyed
		
		// Debug
		private static const LOG_PREFIX:String = "[Sound Instance]";
		private var _verbose:Boolean = false;
		private static var _idCount:uint = 0;
		private var _id:uint = 0;
		
		/**
		 * Create a new sound instance from its track configuration and its manager.
		 */
		public function SoundInstance(trackConfig:TrackConfiguration, manager:SoundManager = null)
		{
			// Check for argument validity
			if (!trackConfig)
				throw new ArgumentError(LOG_PREFIX + " Invalid argument. Track configuration is null.");
			
			// Debug
			_id = _idCount++;
			
			// Setup core members
			_soundConfig = trackConfig.clone(); // Clone config to prevent any live config changes
			_samplingCount = trackConfig.sampling;
			_track = trackConfig.track;
			_type = trackConfig.type;
			
			// Trimming setup
			_trimStartDuration = trackConfig.trimStartDuration;
			_trimEndDuration = trackConfig.trimEndDuration;
			
			// Setup sound transform
			_soundTransform = new SoundTransform();
			
			// Setup custom sampling
			_extractionFunc = feedSamples;
			setupCustomSamplingVars();
			_fakeSound = new flash.media.Sound();
			_fakeSound.addEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);
			
			// Setup manager
			this.manager = manager; // Will trigger sound manager registration
		}
		
		private function setupCustomSamplingVars():void
		{
			// Setup start & end positions
			_endPosition = (_track.length - _trimEndDuration) * SAMPLE_RATE_MS;
			_startPosition = _trimStartDuration * SAMPLE_RATE_MS;
			
			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' is setting up custom sampling vars. Start position: " + _startPosition + ", end position: " + _endPosition);
		}
		
		/**
		 * Destroy sound instance. After this operation, the object should not be accessed anymore.
		 */
		public function destroy():void
		{
			// Cannot destroy twice
			if (_isDestroyed)
				return;
			
			// Mark object as destroyed
			_isDestroyed = true;
			
			// Reset signals
			started.removeAll();
			completed.removeAll();
			paused.removeAll();
			resumed.removeAll();
			stopped.removeAll();
			
			// Unregister events
			if (_fakeSound)
				_fakeSound.removeEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);
			
			// Stop channel
			stopChannel();
			
			// Nullify references
			manager = null; // Will automatically unregister from manager
			_track = null;
			_soundTransform = null;
			_channel = null;
			_fakeSound = null;
			_soundConfig = null;
			_pitchExtractedData = null;
			_extractionFunc = null;
			started = null;
			completed = null;
			stopped = null;
			paused = null;
			resumed = null;
			
			// Dispatch destroy event
			destroyed.dispatch(this);
			destroyed.removeAll();
			destroyed = null;
		}
		
		/**
		 * Indicates whether this sound instance is destroyed.
		 *
		 * A destroyed sound instance should not be accessed anymore.
		 */
		public function get isDestroyed():Boolean
		{
			return _isDestroyed;
		}
		
		//---------------------------------------------------------------------
		//-- Sound Processing
		//---------------------------------------------------------------------
		
		/**
		 * Find next zero crossing position.
		 * 
		 * This method checks both channels at the same time.
		 */
		private static function findZeroCrossingPosition(bytes:ByteArray, startPosition:uint = 0):uint
		{
			// Store bytes array initial position
			var initialPosition:uint = bytes.position;
			
			// Setup starting position
			bytes.position = startPosition;
			
			// Not enough bytes to read two float
			if (bytes.position + 8 >= bytes.length)
				return 0;
			
			// Setup
			var zeroCrossingPosition:uint = 0;
			var l0:Number = bytes.readFloat();
			var r0:Number = bytes.readFloat();
			
			// Look for zero-crossing for both side (stereo)
			while (bytes.position + 8 < bytes.length)
			{
				var l1:Number = bytes.readFloat();
				var r1:Number = bytes.readFloat();
				
				// Find zero crossing on both side
				if (l0 > 0 && l1 < 0 || l0 < 0 && l1 > 0 || l1 == 0 && r0 > 0 && r1 < 0 || r0 < 0 && r1 > 0 || r1 == 0)
				{
					zeroCrossingPosition = bytes.position;
					break;
				}
			}
			
			// Reset position
			bytes.position = initialPosition;
			return zeroCrossingPosition;
		}
		
		/**
		 * Fill a given ByteArray with blank samples.
		 */
		private static function fillBlank(bytes:ByteArray, samples:int):void
		{
			for (var s:int = 0; s < samples; ++s)
			{
				bytes.writeFloat(0);
				bytes.writeFloat(0);
			}
		}
		
		/**
		 * Data sampling handler.
		 * 
		 * <p>
		 * According to AIR requirements, this method must fill between 2048 and 8192 samples (no less, no more).
		 * The number of samples to fill in the event's data is given by `_samplingCount`.
		 * </p>
		 * 
		 * <p>
		 * IMPORTANT FOR DEVS:
		 * <ul>
		 * <li>Never dispatch events during data sampling.</li>
		 * <li>Do not touch sound instance status variables during data sampling.</li>
		 * </ul>
		 * </p>
		 */
		private function onSampleData(e:SampleDataEvent):void
		{
			var samplesFed:Number = 0;
			while (true)
			{
				// Extract samples & write them in the data output buffer
				samplesFed += _extractionFunc(e.data, _samplingCount - samplesFed);
				
				// Still looping & reached the end of the track?
				if ((_readLoopsRemaining > 0 || _infiniteLooping) && samplesFed < _samplingCount)
				{
					// Reduce read remaining loops
					_readLoopsRemaining--;
					
					// Reset the diamond
					_readingTipPos = _startPosition;

					// Continue reading...
					continue;
				}

				// Done
				break;
			}
		}
		
		/**
		 * Simple feeding function without pitch support.
		 * 
		 * It doesn't feed more data than it can. Looping operation should be handled by the caller.
		 */
		private function feedSamples(data:ByteArray, samplesToFeed:uint):Number
		{
			// Read maximum number of bytes from source
			var samplesToRead:Number = Math.min(_endPosition - _readingTipPos, samplesToFeed);

			// Extract & feed data
			var samplesRead:Number = _track.extract(data, samplesToRead, _readingTipPos);

			// Update reading position
			_readingTipPos += samplesRead;

			// Return number of written samples
			return samplesRead;
		}

		/**
		 * Feeding function which supports pitching capability.
		 * 
		 * It doesn't feed more data than it can. Looping operation should be handled by the caller.
		 * 
		 * This method has been inspired by Andre Michelle's implementation found here: http://blog.andre-michelle.com/2009/pitch-mp3/
		 */
		private function feedPitchedSamples(data:ByteArray, samplesToFeed:uint):Number
		{
			// Reuse byte array instead of recreation
			_pitchExtractedData.position = 0;
			
			// Setup core variables
			var scaledBlockSize:Number = samplesToFeed * _pitch;
			var positionInt:int = _readingTipPos;
			var alpha:Number = _readingTipPos - positionInt;
			var positionTargetNum:Number = alpha;
			var positionTargetInt:int = -1;

			// Compute number of samples needed to process block (+2 for interpolation)
			var samplesNeeded:int = Math.ceil(scaledBlockSize) + 2;
			
			// Extract samples
			var samplesRead:int = _track.extract(_pitchExtractedData, samplesNeeded, positionInt);
			var samplesToWrite:int = samplesRead == samplesNeeded ? samplesToFeed : samplesRead / _pitch;

			// For all samples required to be written
			var l0:Number;
			var r0:Number;
			var l1:Number;
			var r1:Number;
			for (var i:int = 0 ; i < samplesToWrite ; ++i)
			{
				// Avoid reading equal samples, if rate < 1.0
				if (int(positionTargetNum) != positionTargetInt)
				{
					positionTargetInt = positionTargetNum;
					
					// Set target read position
					_pitchExtractedData.position = positionTargetInt << 3;
	
					// Read two stereo samples for linear interpolation
					l0 = _pitchExtractedData.readFloat();
					r0 = _pitchExtractedData.readFloat();
					l1 = _pitchExtractedData.readFloat();
					r1 = _pitchExtractedData.readFloat();
				}
				
				// Write interpolated amplitude into the stream
				data.writeFloat(l0 + alpha * (l1 - l0));
				data.writeFloat(r0 + alpha * (r1 - r0));
				
				// Increase the target position
				positionTargetNum += _pitch;
				
				// Increase fraction and keep only the fractional part
				alpha += _pitch;
				alpha -= int(alpha);
			}

			// Update reading tip position
			_readingTipPos += scaledBlockSize;

			// Return number of written samples
			return samplesToWrite;
		}
		
		//---------------------------------------------------------------------
		//-- Sound Control
		//---------------------------------------------------------------------
		
		/**
		 * Play the sound instance.
		 * 
		 * @param volume The initial volume
		 * @param startTime Start position in milliseconds
		 * @param loops Number of sound repetitions. -1 for infinite looping.
		 */
		public function play(volume:Number = VOLUME_MAX, startTime:Number = 0, loops:int = 0):SoundInstance
		{
			return playInternal(volume, startTime, loops);
		}
		
		/**
		 * Internal play.
		 *
		 * Beware: It can trigger sound completion (and destruction!) if startTime equals totalLength!
		 */
		private function playInternal(volume:Number = VOLUME_MAX, startTime:Number = 0, loops:int = 0, startPaused:Boolean = false):SoundInstance
		{
			// Setup params
			_loops = loops;
			_infiniteLooping = loops < 0;
			
			// Stop existing channel
			if (_channel)
			{
				stopChannel();
				_channel = null;
			}
			
			// Check for position validity
			if (startTime < 0 || startTime > totalLength)
				throw new ArgumentError(LOG_PREFIX + " Invalid position. Value must be in the following interval [0.." + totalLength + "]");
			
			// Direct end case (prevent (startTime % length == 0))
			if (startTime == totalLength)
			{
				complete();
				return this;
			}
			
			// Reset pause / resume status
			_isPaused = startPaused;
			_pauseTime = startPaused ? startTime : 0;

			// Start to play the sound
			_startTime = startTime;

			// Detect if the sound is a standard one (native MP3, no trimming & no pitch)
			_isStandardSound = _track is Mp3Track && _pitch == PITCH_DEFAULT && _trimStartDuration == 0 && _trimEndDuration == 0;

			if (_isStandardSound)
			{
				// Compute past duration & channel start time
				_standardSoundLoopPosition = Math.floor(startTime / length) * length;
				startTime = startTime % length;
			}
			else
			{
				// Diamond setup
				_readingTipPos = _startPosition + int((startTime % length) * SAMPLE_RATE_MS); // Setup the diamond
				_readLoopsRemaining = loops - Math.floor(startTime / length); // Compute remaining loops from start time

				// Pitch setup in case pitch is set
				pitchStartPosition = _startTime;
			}
			
			// Acquire a channel if sound doesn't start paused
			if (!startPaused)
			{
				// Capacity check if Sound Manager available
				if (manager == null || manager.getPlayingSoundInstancesCount() < manager.maxChannelCapacity)
				{
					// Acquire a sound channel
					if (_isStandardSound)
						_channel = (_track as Mp3Track).sound.play(startTime, 0, _isMuted ? new SoundTransform(0) : _soundTransform);
					else
						_channel = _fakeSound.play(startTime, -1, _isMuted ? new SoundTransform(0) : _soundTransform);
				}
				else
				{
					_channel = null;
				}

				// Channel can be null if maximum number of sound channels available is reached or if no sound card is available.
				if (_channel == null)
				{
					var errorMessage:String = LOG_PREFIX + " Impossible to acquire a sound channel for sound '" + _type + "#" + _id + "'. The maximum number of channels has been reached or there is no sound card available.";
					if (safeChannelAquisition)
						trace(errorMessage);
					else
						throw new IllegalOperationError(errorMessage);

					// Put the sound in hold
					_isPaused = true;
				}
				else
				{
					// Listen to sound completion
					_channel.addEventListener(Event.SOUND_COMPLETE, onSoundComplete);
				}

				// Set volume (+check) after having created the channel
				this.volume = volume;
			}
			
			// Sound started (only once)
			if (!_isStarted)
			{
				_isStarted = true;
				started.dispatch(this);
			}
			
			return this;
		}
		
		/**
		 * Stop the sound.
		 *
		 * Stopped event will then be dispatched.
		 */
		public function stop():void
		{
			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' stopped.");
			
			// Stop channel if playing
			if (_channel)
			{
				stopChannel();
				_channel = null;
			}
			
			// Reset status
			_isStarted = false;
			_pauseTime = 0;
			_isPaused = false;
			
			// Dispatch stopped event
			stopped.dispatch(this);
		}
		
		/**
		 * Complete the sound.
		 *
		 * Completed event will then be dispatched.
		 */
		private function complete():void
		{
			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' complete.");
			
			// Dispatch completion event
			completed.dispatch(this);
			
			// Destroy instance if requested
			if (_destroyOnComplete)
				destroy();
		}
		
		/**
		 * Get muting status of current sound.
		 */
		public function get isMuted():Boolean
		{
			return _isMuted;
		}
		
		/**
		 * Mute / unmute current sound.
		 *
		 * - A muted sound continues to play.
		 * - Volume modifications of a muted sound won't unmute the sound but will be kept.
		 * - Panning modifications of a muted sound won't unmute the sound but will be kept.
		 */
		public function set isMuted(value:Boolean):void
		{
			// Update muting status
			_isMuted = value;
			
			// Update channel sound transform if any
			if (_channel != null)
				_channel.soundTransform = _isMuted ? new SoundTransform(0, _soundTransform.pan) : _soundTransform;
		}
		
		/**
		 * Pause currently playing sound.
		 *
		 * Use resume() to continue playback. Pause / resume is supported for a single sound only.
		 */
		public function pause():SoundInstance
		{
			// Check for channel validity
			if (_channel == null)
				return this;
			
			// Pause
			_pauseTime = position;
			_isPaused = true;
			
			// stop the channel
			stopChannel();
			_channel = null;
			
			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' paused. Pause time:" + _pauseTime);
			
			// Dispatch event
			paused.dispatch(this);
			
			// Return instance for chaining
			return this;
		}
		
		/**
		 * Resume a paused sound.
		 */
		public function resume():SoundInstance
		{
			// Already running...
			if (!_isPaused)
				return this;
			
			// Resume
			_isPaused = false;
			
			// Play at current pause position
			playInternal(volume, _pauseTime, loops);
			
			// Beware: play can trigger completion right away & destruction in the time!
			if (_isDestroyed)
				return this;
			
			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' resumed. Resume time:" + _pauseTime);
			
			// Dispatch event
			resumed.dispatch(this);
			
			// Return instance for chaining
			return this;
		}
		
		/**
		 * Indicates whether this sound is currently paused.
		 */
		public function get isPaused():Boolean
		{
			return _isPaused;
		}
		
		/**
		 * Set pausing status.
		 */
		public function set isPaused(value:Boolean):void
		{
			if (value)
				pause();
			else
				resume();
		}
		
		/**
		 * Indicates whether this sound is currently playing.
		 */
		public function get isPlaying():Boolean
		{
			return _channel != null;
		}
		
		/**
		 * Indicates whether this sound instance has started (play() method has been called and succeeded once).
		 */
		public function get isStarted():Boolean
		{
			return _isStarted;
		}
		
		/**
		 * Get the actual length of the sound in milliseconds with trimming options.
		 *
		 * Note: This doesn't take into account loops. For length with looping options, have a look to `totalLength` method.
		 */
		public function get length():Number
		{
			return _track.length - (_trimStartDuration + _trimEndDuration);
		}
		
		/**
		 * Get the total length of the sound in milliseconds with trimming & looping options.
		 *
		 * Note: If infinite looping is active, `Number.POSITIVE_INFINITY` will be returned.
		 */
		public function get totalLength():Number
		{
			if (_infiniteLooping)
				return Number.POSITIVE_INFINITY;
			else
				return length * (_loops + 1);
		}

		/**
		 * Position ratio in the current loop.
		 * 
		 * Each loop start at 0 and ends at 1.0.
		 */
		public function get positionRatioInLoop():Number
		{
			// Prevent potential devision by zero
			var length:Number = this.length;
			if (length <= 0)
				return 0;
			
			// Compute & return the local ratio
			return (position % length) / length;
		}
		
		/**
		 * Set the normalized position of the sound (between 0..1).
		 *
		 * Note: Loops are part of the equation.
		 *       Infinite looping sound will always return 0.
		 */
		public function get positionRatio():Number
		{
			// Prevent potential devision by zero
			var totalLength:Number = this.totalLength;
			if (totalLength <= 0)
				return 0;
			
			// Compute & return the ratio
			return position / totalLength;
		}
		
		/**
		 * Set position with normalized position of sound.
		 *
		 * Note: Loops are part of the equation.
		 */
		public function set positionRatio(value:Number):void
		{
			// Check for position ratio validity
			if (value < VOLUME_MIN || value > VOLUME_MAX)
				throw new ArgumentError(LOG_PREFIX + " Invalid position ratio. Value must be in the following interval [" + VOLUME_MIN + ".." + VOLUME_MAX + "]");
			
			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' position ratio changed to:" + value);
			
			// Update the position based on the total length
			position = value * totalLength;
		}
		
		/**
		 * Get the current position of the sound in milliseconds.
		 * 
		 * This is the actual position in the track (non-pitched).
		 */
		public function get position():Number
		{
			// Not started yet or paused
			if (_channel == null)
				return _pauseTime;

			// Standard sound case
			if (_isStandardSound)
				return _channel.position + _standardSoundLoopPosition;

			// When the pitch parameter is set, the past time is influenced by the pitch
			if (_pitch != PITCH_DEFAULT)
				return _pitchStartPosition + (getTimer() - _pitchStartTimer) * _pitch;

			// Playing sound
			return _channel.position;
		}
		
		/**
		 * Set the current position of the sound in milliseconds.
		 */
		public function set position(value:Number):void
		{
			// Check for position validity
			if (value < 0 || value > totalLength)
				throw new ArgumentError(LOG_PREFIX + " Invalid position. Value must be in the following interval [0.." + totalLength + "]");
			
			// Update paused sound
			if (_isPaused || !_isStarted)
				_pauseTime = value;
			
			// Update playing sound
			if (_channel != null)
			{
				// Stop the channel
				stopChannel();
				
				// Play the sound at the new position with the same parameters
				playInternal(volume, value, _loops, isPaused);
			}

			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' position changed to " + value + " ms.");
		}
		
		/**
		 * Get the volume.
		 *
		 * Returns a value between 0 and 1.
		 */
		public function get volume():Number
		{
			return _volume;
		}
		
		/**
		 * Set the volume.
		 *
		 * The final volume is mixed with the sound manager volume.
		 *
		 * @see mixedVolume
		 */
		public function set volume(value:Number):void
		{
			// Update the voume value, but respect the mute flag.
			if (value < VOLUME_MIN)
				value = VOLUME_MIN;
			else if (value > VOLUME_MAX || isNaN(volume))
				value = VOLUME_MAX;
			
			// Set internal volume
			_volume = value;
			
			// Update current sound transform
			_soundTransform.volume = mixedVolume;
			
			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' volume updated to " + value + ". Mixed volume: " + mixedVolume);
			
			// Apply sound transform if possible & not muted
			if (!_isMuted && _channel)
				_channel.soundTransform = _soundTransform;
		}
		
		/**
		 * Return the combined manager volume and sound instance volume.
		 */
		public function get mixedVolume():Number
		{
			return _volume * (_manager ? _manager.volume : 1.0);
		}
		
		/**
		 * Get the left-to-right panning of the sound, ranging from -1 (full pan left) to 1 (full pan right).
		 */
		public function get pan():Number
		{
			return _soundTransform.pan;
		}
		
		/**
		 * Set the left-to-right panning of the sound, ranging from -1 (full pan left) to 1 (full pan right).
		 */
		public function set pan(value:Number):void
		{
			// Clamp panning from -1.0 to 1.0
			value = Math.max(-1.0, Math.min(value, 1.0));
			
			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' pan set to " + value + ".");
			
			// Update pan
			_soundTransform.pan = value;
			
			// Apply sound transform if possible & not muted
			if (!_isMuted && _channel)
				_channel.soundTransform = _soundTransform;
		}

		/**
		 * Get the pitch.
		 */
		public function get pitch():Number
		{
			return _pitch;
		}
		
		/**
		 * Set the pitch.
		 */
		public function set pitch(value:Number):void
		{
			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' pitch set to " + value + ".");
			
			// Update pitch start position with the current position
			if (_infiniteLooping)
				pitchStartPosition = positionRatioInLoop;
			else
				pitchStartPosition = position;

			// Update pitch
			_pitch = value;

			// Assign the right extraction function according to pitching value
			_extractionFunc = _pitch == PITCH_DEFAULT ? feedSamples : feedPitchedSamples;

			// Leave standard sound
			if (_isStandardSound && _pitch != PITCH_DEFAULT)
			{
				// Debug
				if (_verbose)
					trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' is not anymore a standard sound.");

				// Restart sound with proper configuration
				playInternal(volume, position, loops, isPaused);
			}
		}

		/**
		 * Used to update start pitching position & therefore reset the pitch start time
		 */
		private function set pitchStartPosition(position:Number):void
		{
			// Update position
			_pitchStartPosition = position;

			// Important: Reset real-time stopwatch
			_pitchStartTimer = getTimer();
		}
		
		/**
		 * Get the Sound Manager.
		 */
		public function get manager():SoundManager
		{
			return _manager;
		}
		
		/**
		 * Set the Sound Manager.
		 *
		 * This will automatically trigger unregistration from the previous Sound Manager & registration to the new one.
		 */
		public function set manager(value:SoundManager):void
		{
			// Remove sound from previous sound manager
			if (_manager)
				_manager.removeSoundInstance(this);
			
			// Update sound manager
			_manager = value;
			
			// Add sound in the new sound manager
			if (_manager)
				_manager.addSoundInstance(this);
			
			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound '" + _type + "#" + _id + "' manager changed to " + value + ".");
			
			// Update (mixed) volume
			this.volume = volume;
		}
		
		/**
		 * Return the total loops or -1 if looping is infinite.
		 */
		public function get loops():int
		{
			return _infiniteLooping ? -1 : _loops;
		}
		
		/**
		 * Return the remaining loops or -1 if looping is infinite.
		 */
		public function get loopsRemaining():int
		{
			// Infinite looping case
			if (_infiniteLooping)
				return -1;
			
			// Compute remaining loops based on the actual channel position
			return loops - Math.floor(position / length);
		}
		
		/**
		 * Type
		 */
		public function get type():String
		{
			return _type;
		}
		
		/**
		 * Get automatic sound instance destruction flag on sound complete.
		 */
		public function get destroyOnComplete():Boolean
		{
			return _destroyOnComplete;
		}
		
		/**
		 * Set automatic sound instance destruction flag on sound complete.
		 */
		public function set destroyOnComplete(value:Boolean):void
		{
			_destroyOnComplete = value;
		}
		
		/**
		 * Get verbose mode activity status.
		 */
		public function get verbose():Boolean
		{
			return _verbose;
		}
		
		/**
		 * Set verbose mode activity.
		 */
		public function set verbose(value:Boolean):void
		{
			_verbose = value;
		}
		
		/**
		 * Get the sound instance unique id.
		 */
		public function get id():uint
		{
			return _id;
		}
		
		//---------------------------------------------------------------------
		//-- Internal
		//---------------------------------------------------------------------
		
		/**
		 * Stop the currently playing channel.
		 */
		private function stopChannel():void
		{
			// Check if channed is valid
			if (!_channel)
				return;
			
			// Unregister from complete event
			_channel.removeEventListener(Event.SOUND_COMPLETE, onSoundComplete);
			
			// Attempt to stop the channel
			try
			{
				_channel.stop();
			}
			catch (e:Error)
			{
				trace(LOG_PREFIX + " Impossible to stop the channel. Error: " + e.message);
			}
		}
		
		//---------------------------------------------------------------------
		//-- Event handlers
		//---------------------------------------------------------------------
		
		/**
		 * On sound complete.
		 */
		private function onSoundComplete(e:Event):void
		{
			// Handle looping for standard sound
			if (_isStandardSound)
			{
				// HACK because _channel.position is not exactly equals to length on sound completed.
				// Stop the channel & update pause time to get the right position when requesting it.
				stopChannel();
				_channel = null;
				_pauseTime = _standardSoundLoopPosition + length;

				// Debug
				if (_verbose)
					trace(LOG_PREFIX + " Standard sound completed. Loops remaining: " + loopsRemaining);

				// Replay?
				if (_infiniteLooping || loopsRemaining >= 0)
				{
					// Continue playing...
					playInternal(volume, position, loops);
					return;
				}
			}

			// Complete the sound
			complete();
		}
	}
}