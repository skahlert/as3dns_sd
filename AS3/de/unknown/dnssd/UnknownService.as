//complete
package de.unknown.dnssd
{
	import flash.display.*;
	import flash.events.*;
	
	public class UnknownService extends Sprite implements DNSSDService
	{
		protected var fNativeContext:int; //Private Storage for Native C functions
		protected var fListener:BaseListener;
		
		public function UnknownService(listener:BaseListener)
		{
			fNativeContext=0;
			fListener=listener;
		}

		public function stop():void
		{
			this.HaltOperation();
		}
		
		protected function BlockForData():int
		{
			return CNativeImplementation.BlockForData(this);
		}
		protected function ProcessResults():int
		{
			return CNativeImplementation.ProcessResults(this);
		}
		
		protected function HaltOperation():void
		{
			CNativeImplementation.HaltOperation(this);
		}
		
		protected function ThrowOnErr(rc:int):void
		{
			if (rc!=0)
				throw new UnknownDNSSDError(rc);
		}
		
		
		/*
		* Since AS3 doesn't support threads we need to do this event-based
		*/
		
		protected function run(e:Event):void
		{
			var result:int = this.BlockForData();
			
			if (fNativeContext == 0)
			{
				removeEventListener(Event.RENDER,run);
			}	// Some other thread stopped our DNSSD operation; time to terminate this Event-Loop
			
			if (result == 0) return;		// If BlockForData() said there was no data, go back and block again
			
			result = this.ProcessResults();
			
			if (fNativeContext == 0) 
			{
				removeEventListener(Event.RENDER,run);
			}	// Event listener stopped its own DNSSD operation; terminate this thread
			
			
			if (result != 0) {
				fListener.operationFailed(this, result);
				removeEventListener(Event.RENDER,run);
			 }	// If error, notify listener
			
		}
		
		
	}
}