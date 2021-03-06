﻿package flip.filters
{
	import flash.display.BitmapData;
	
	public class FlInvertFilter implements IFlFilter
	{
		
		public function FlInvertFilter ()
		{
			
		}
		
		public function render ( screen : BitmapData, buffer : BitmapData ) : void
		{
			var c:uint;
			for(var y:uint = 0; y < screen.height; y++)
			{
				for(var x:uint = 0; x < screen.width; x++)
				{
					c = screen.getPixel(x,y);
					c = 0xFF - (c & 0xFF);
					screen.setPixel(x,y,(c << 16) | (c << 8) | c);
				}
			}
		}
	}
}