/**
*	A class that makes it easy to manage
*	a keymap for the Chip-8 keypad
*/
package flip.keymap
{
	import flash.ui.Keyboard;
	
	public class KeyMap
	{
		/**
		*	Identifier name of the map
		*/
		public var name : String;
		/**
		*	Contains the keycode for each keypad key
		*/
		protected var _map : Vector.<uint>;
		/**
		*	Contains the keypad presses
		*/
		private var _keys : Vector.<Boolean>;
		
		public function KeyMap (name:String="default")
		{
			this.name = name;
			_map = new Vector.<uint>(16,true);
			_keys = new Vector.<Boolean>(16,true);
			
			defaultVal();
		}
		
		/**
		*	Sets this keymap to default values
		*/
		protected function defaultVal () : void
		{
			_map[ 0 ]	= Keyboard.NUMBER_0;
			_map[ 1 ]	= Keyboard.NUMBER_1;
			_map[ 2 ]	= Keyboard.NUMBER_2;
			_map[ 3 ]	= Keyboard.NUMBER_3;
			_map[ 4 ]	= Keyboard.NUMBER_4;
			_map[ 5 ]	= Keyboard.NUMBER_5;
			_map[ 6 ]	= Keyboard.NUMBER_6;
			_map[ 7 ]	= Keyboard.NUMBER_7;
			_map[ 8 ]	= Keyboard.NUMBER_8;
			_map[ 9 ]	= Keyboard.NUMBER_9;
			_map[ 10 ]	= Keyboard.A;
			_map[ 11 ]	= Keyboard.B;
			_map[ 12 ]	= Keyboard.C;
			_map[ 13 ]	= Keyboard.D;
			_map[ 14 ]	= Keyboard.E;
			_map[ 15 ]	= Keyboard.F;
			
		}
		
		/**
		*	Press a key
		*/
		public function pressKey ( code : uint ) : void
		{
			for(var i:uint = 0; i < 16; i++)
			{
				if(_map[i] == code)	// If the key is mapped to the keypad
				{
					_keys[i] = true;	// Press that key
					i = 16;				// Break loop
				}
			}
		}
		
		/**
		*	Release a key
		*/
		public function releaseKey ( code : uint ) : void
		{
			for(var i:uint = 0; i < 16; i++)
			{
				if(_map[i] == code)	// If the key is mapped to the keypad
				{
					_keys[i] = false;	// Release that key
					i = 16;				// Break loop
				}
			}
		}
		
		/**
		*	Get the key state of the keypad
		*/
		public function key ( i:uint ) : Boolean
		{
			return _keys[i];
		}
		
		/**
		*	Sets all the key states do false
		*/
		public function reset () : void
		{
			//_keys.forEach( new Function (item:Boolean,index:int,vec:Vector.<Boolean>) {vec[index] = false;} );
			for each(var i:int in _keys)
			{
				_keys[i] = false;
			}
		}
	}
}