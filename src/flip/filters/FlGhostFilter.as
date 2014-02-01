package flip.filters
{
	import flash.display.BitmapData;
	
	public class FlGhostFilter implements IFlFilter
	{
		private var _amount : Number;
		
		public function FlGhostFilter ( amount : Number = .8 )
		{
			_amount = amount;
		}
		
		public function render ( screen : BitmapData, buffer : BitmapData ) : void
		{
			var ca:uint, cb:uint, ra:uint, rb:uint, ga:uint, gb:uint, ba:uint, bb:uint;
			
			for(var y:uint = 0; y < screen.height; y++)
			{
				for(var x:uint = 0; x < screen.width; x++)
				{
					ca = screen.getPixel(x,y);
					cb = buffer.getPixel(x,y);
					
					ra = ca >> 16;
					rb = cb >> 16;
					
					ga = (ca & 0xFF00) >> 8;
					gb = (cb & 0xFF00) >> 8;
					
					ba = ca & 0xFF;
					bb = cb & 0xFF;
					
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
		}
	}
}