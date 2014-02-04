package flip.keymap
{
	import flash.ui.Keyboard;
	public class GameMap extends KeyMap
	{
		
		public function KeyboardMap ()
		{
			super("Game");
			/* Map
			1 2 3 C
			4 5 6 D
			7 8 9 E
			A 0 B F
			*/
			_map[ 2 ]	= Keyboard.UP;
			_map[ 4 ]	= Keyboard.LEFT;
			_map[ 5 ]	= Keyboard.SPACE;
			_map[ 6 ]	= Keyboard.RIGHT;
			_map[ 8 ]	= Keyboard.DOWN;
		}
	}
}