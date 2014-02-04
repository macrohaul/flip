package flip.debug
{
	
	public class FlipDebugger
	{
		/**
		*	Wether to debug or not
		*/
		public var debug : Boolean;
		/**
		*	Callback function called when debugger updates
		*/
		public var callback : Function;
		/**
		*	Last log message
		*/
		private var _msg : String;
		/**
		*	Current program counter
		*/
		private var _pc : uint;
		/**
		*	Current Index register
		*/
		private var _i : uint;
		/**
		*	Current opcode
		*/
		private var _op : uint;
		/**
		*	Registry reference
		*/
		private var _reg : Vector.<uint>;
		
		public function FlipDebugger ()
		{
			debug = false;
		}
		
		/**
		*	Log a message with important variables
		*/
		public function log ( pc:uint, I:uint, op:uint, msg:String ) : void
		{
			if(debug)
			{
				_pc	= pc;
				_i	= I;
				_op	= op;
				_msg = "[" + (pc - 2).toString(16) + " : " + I.toString(16) + "] " + op.toString(16) + " - " + msg;
				update();
			}
		}
		
		/**
		*	Internal helper function for callback update
		*/
		private function update () : void
		{
			if(callback != null)
				callback();
		}
		
		public function setRegistry ( r:Vector.<uint> ) : void
		{
			_reg = r;
		}
		
		public function get programCounter () : uint { return _pc; }
		public function get opCode () : uint { return _op; }
		public function get I () : uint { return _i; }
		public function get message () : String { return _msg; }
		public function get registry () : Vector.<uint> { return _reg; }
	}
}