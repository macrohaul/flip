package flip.filters
{
	import flash.display.BitmapData;
	
	public interface IFlFilter
	{
		
		function render ( screen : BitmapData, buffer : BitmapData ) : void;
	}
}