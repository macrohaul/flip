package flip.filters
{
	import flash.display.BitmapData;
	
	public class FlGhostFilter implements IFlFilter
	{
		private var _amount : Number = .8;
		private var _emount : Number = .2;
		
		public function FlGhostFilter ()
		{
			
		}
		
		public function render ( screen : BitmapData, buffer : BitmapData ) : void
		{
			var c:uint, ra:uint, ga:uint, ba:uint, rb:uint, gb:uint, bb:uint;
			
			for(var y:uint = 0; y < screen.height; y++)
			{
				for(var x:uint = 0; x < screen.width; x++)
				{
					c = screen.getPixel(x,y);
					ra = c >> 16;
					ga = (c >> 8) & 0xFF;
					ba = c & 0xFF;
					
					c = buffer.getPixel(x,y);
					rb = c >> 16;
					gb = (c >> 8) & 0xFF;
					bb = c & 0xFF;
					
					ra = Math.min( ra + (rb * _amount), 255 );
					ga = Math.min( ga + (gb * _amount), 255 );
					ba = Math.min( ba + (bb * _amount), 255 );
					
					screen.setPixel(x,y, (ra << 16) | (ga << 8) | ba);
				}
			}
		}
		
		public function set amount ( n:Number ) : void
		{
			_amount = Math.max( Math.min(n, 1), 0);
			_emount = 1 - _amount;
		}
	}
}