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
	import flash.utils.ByteArray;
	import flash.errors.IllegalOperationError;
	
	/**
	 * Base track class.
	 *
	 * This class wraps sound data & allows to retrieve it.
	 *
	 * @author Aurelien Da Campo
	 */
	public class Track
	{
		/**
		 * The length of the current sound in milliseconds.
		 */
		public function get length():Number
		{
			throw new IllegalOperationError("[Track] Abstract method.");
		}
		
		/**
		 * Extract samples.
		 *
		 * @param target A ByteArray object in which the extracted sound samples are placed.
		 * @param length The number of sound samples to extract. A sample contains both the left and right channels â€” that is, two 32-bit floating-point values.
		 * @param startPosition The sample at which extraction begins. If you don't specify a value, the first call to Sound.extract() starts at the beginning of the sound; subsequent calls without a value for startPosition progress sequentially through the file.
		 * @return The number of samples written to the ByteArray specified in the target parameter.
		 */
		public function extract(target:ByteArray, length:Number, startPosition:Number = -1):Number
		{
			throw new IllegalOperationError("[Track] Abstract method.");
		}
		
		/**
		 * Destroy the object and make it unusable.
		 */
		public function destroy():void
		{
			throw new IllegalOperationError("[Track] Abstract method.");
		}
	}
}