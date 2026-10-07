// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019-2026 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio.test
{
	public class Assert
	{
		public static function isTrue(value:Boolean, message:String):void
		{
			if (!value)
				throw new Error(message);
		}

		public static function isFalse(value:Boolean, message:String):void
		{
			if (value)
				throw new Error(message);
		}

		public static function isNull(value:Object, message:String):void
		{
			if (value != null)
				throw new Error(message);
		}

		public static function isNotNull(value:Object, message:String):void
		{
			if (value == null)
				throw new Error(message);
		}

		public static function equalsInt(value:int, expected:int, message:String):void
		{
			if (value != expected)
				throw new Error("Value: " + value + ", expected: " + expected + ". Message: " + message);
		}

		/**
		 * Checks that a number is within <code>epsilon</code> of the expected one. Infinite values must match exactly.
		 */
		public static function equalsNumber(value:Number, expected:Number, epsilon:Number, message:String):void
		{
			if (!(value == expected || Math.abs(value - expected) <= epsilon))
				throw new Error("Value: " + value + ", expected: " + expected + " (+/- " + epsilon + "). Message: " + message);
		}

		/**
		 * Checks that calling the block, a function without parameter, raises an error of the given class.
		 */
		public static function throws(errorClass:Class, block:Function, message:String):void
		{
			try
			{
				block();
			}
			catch (error:Error)
			{
				if (error is errorClass)
					return;

				throw new Error("Raised: " + error + ", expected: " + errorClass + ". Message: " + message);
			}

			throw new Error("Nothing raised, expected: " + errorClass + ". Message: " + message);
		}
	}
}
