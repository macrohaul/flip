package flip.filters
{
	import flash.display.BitmapData;
	
	public class FlAntiFlickerFilter implements IFlFilter
	{
		
		public function FlAntiFlickerFilter ()
		{
			
		}
		
		public function render ( screen : BitmapData, buffer : BitmapData ) : void
		{
			for(var y:uint = 0; y < screen.height; y++)
			{
				for(var x:uint = 0; x < screen.width; x++)
				{
					screen.setPixel(x,y, screen.getPixel(x,y) | buffer.getPixel(x,y) );
				}
			}
		}
	}
}