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
	 * An asynchronous test.
	 */
	public interface ITestAsync
	{
		/**
		 * Executes the test.
		 *
		 * <p>`onSuccess` prototype: `function():void`</p>
		 * <p>`onFail` prototype: `function(error:Error):void`</p>
		 */
		function executeAsync(onSuccess:Function, onFail:Function):void;
	}
}
