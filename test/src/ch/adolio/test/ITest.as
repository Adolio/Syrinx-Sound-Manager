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
	/**
	 * A basic synchronous test.
	 */
	public interface ITest
	{
		/**
		 * Executes the test.
		 *
		 * <p>This method should raise an <code>Error</code> in case of failure.</p>
		 */
		function execute():void;
	}
}
