package flip.keymap
{
	import flash.ui.Keyboard;
	public class KeyboardMap extends KeyMap
	{
		
		public function KeyboardMap ()
		{
			super("Keyboard");
			/* Map
			1 2 3 C		1 2 3 4
			4 5 6 D		Q W E R
			7 8 9 E		A S D F
			A 0 B F		Z X C V
			*/
			_map[ 0 ]	= Keyboard.X;
			_map[ 1 ]	= Keyboard.NUMBER_1;
			_map[ 2 ]	= Keyboard.NUMBER_2;
			_map[ 3 ]	= Keyboard.NUMBER_3;
			_map[ 4 ]	= Keyboard.Q;
			_map[ 5 ]	= Keyboard.W;
			_map[ 6 ]	= Keyboard.E;
			_map[ 7 ]	= Keyboard.A;
			_map[ 8 ]	= Keyboard.S;
			_map[ 9 ]	= Keyboard.D;
			_map[ 10 ]	= Keyboard.Z;
			_map[ 11 ]	= Keyboard.C;
			_map[ 12 ]	= Keyboard.NUMBER_4;
			_map[ 13 ]	= Keyboard.R;
			_map[ 14 ]	= Keyboard.F;
			_map[ 15 ]	= Keyboard.V;
		}
	}
}