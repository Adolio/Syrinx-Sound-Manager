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
	import flash.utils.setTimeout;

	/**
	 * Base of the asynchronous tests made of scenarios run one after the other.
	 *
	 * A scenario (<code>function(next:Function):void</code>) calls <code>next</code> once its checks are done. Code
	 * running later than the scenario call itself must go through <code>attempt</code> or <code>defer</code>, so
	 * that its errors fail the test.
	 */
	public class ScenariosTestAsync implements ITestAsync
	{
		private var _onSuccess:Function;
		private var _onFail:Function;

		public function executeAsync(onSuccess:Function, onFail:Function):void
		{
			_onSuccess = onSuccess;
			_onFail = onFail;

			runNextScenario(createScenarios());
		}

		/**
		 * Returns the scenarios to run, in order.
		 */
		protected function createScenarios():Array
		{
			throw new Error("Abstract method.");
		}

		/**
		 * Runs a block & fails the test if it raises an error.
		 */
		protected function attempt(block:Function):void
		{
			try
			{
				block();
			}
			catch (error:Error)
			{
				_onFail(error);
			}
		}

		/**
		 * Runs a block after a delay in milliseconds, at the earliest once the current call stack, including any
		 * signal dispatch in progress, is over.
		 */
		protected function defer(block:Function, delay:int = 0):void
		{
			setTimeout(function():void { attempt(block); }, delay);
		}

		private function runNextScenario(scenarios:Array):void
		{
			if (scenarios.length == 0)
			{
				_onSuccess();
				return;
			}

			var scenario:Function = scenarios.shift();
			attempt(function():void
			{
				scenario(function():void { runNextScenario(scenarios); });
			});
		}
	}
}
