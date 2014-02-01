package flip.filters
{
	import flash.display.BitmapData;
	
	public class FlGhostFilter implements IFlFilter
	{
		private var _amount : Number = .8;
		
		public function FlGhostFilter ()
		{
			
		}
		
		public function render ( screen : BitmapData, buffer : BitmapData ) : void
		{
			var ca:uint, cb:uint;
			
			for(var y:uint = 0; y < screen.height; y++)
			{
				for(var x:uint = 0; x < screen.width; x++)
				{
					ca = screen.getPixel(x,y) & 0xFF;
					
					cb = buffer.getPixel(x,y) & 0xFF;
					
					ca = Math.min( ca + (cb * _amount), 255 );
					
					screen.setPixel(x,y, (ca << 16) | (ca << 8) | ca);
				}
			}
		}
		
		public function set amount ( n:Number ) : void
		{
			_amount = Math.max( Math.min(n, 1), 0);
		}
	}
}