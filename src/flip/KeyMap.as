/**
*	A class that makes it easy to manage
*	a keymap for the Chip-8 keypad
*/
package flip
{
	
	public class KeyMap
	{
		/**
		*	Contains the keycode for each keypad key
		*/
		private var _map : Vector.<uint>;
		/**
		*	Contains the keypad presses
		*/
		private var _keys : Vector.<Boolean>;
		
		public function KeyMap ()
		{
			_map = new Vector.<uint>(16,true);
			_keys = new Vector.<Boolean>(16,true);
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
	}
}