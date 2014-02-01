package flip
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	import flash.utils.Endian;
	import flash.events.TimerEvent;
	
	public class Flip extends Bitmap
	{
		[Embed(source="../assets/PONG",mimeType="application/octet-stream")]
		public static var DEFAULT_APP : Class;
		
		/**
		*	Screen buffer
		*/
		private var _buffer : BitmapData;
		private var _drawFlag : Boolean;
		
		private var _timer : Timer;
		private const FRAME_RATE : uint	= 120;
		private var _period : Number = 1000 / FRAME_RATE;
		private var _beforeTime : int;
		private var _afterTime : int;
		private var _timeDiff : int;
		private var _sleepTime : uint;
		private var _overSleepTime : uint;
		private var _excess : uint;
		
		private var _curCycle : uint;
		
		/////////////////////////////////////////////////////////////////////// Machine related variables
		
		/**
		*	Current opcode
		*/
		private var _opcode : uint;
		/**
		*	Machine memory
		*/
		private var _memory : Vector.<uint>;
		/**
		*	Program (or memory) counter
		*/
		private var _pc : uint;
		/**
		*	CPU register
		*/
		private var V : Vector.<uint>;
		/**
		*	Register index
		*/
		private var I : uint;
		/**
		*	System delay timer
		*/
		private var _delayTimer : uint;
		/**
		*	System sound timer
		*/
		private var _soundTimer : uint;
		/**
		*	Interpreter stack
		*	Used when calling subroutines
		*/
		private var _stack : Vector.<uint>;
		/**
		*	Stack pointer
		*/
		private var _sp : uint;
		/**
		*	Screen memory
		*/
		private var _vram : Vector.<Boolean>;
		/**
		*	Stores key presses
		*/
		private var _key : Vector.<Boolean>;
		/**
		*	Font table for the Chip-8 fontset
		*/
		private const _fontset : Array =
		[
			0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
			0x20, 0x60, 0x20, 0x20, 0x70, // 1
			0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
			0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
			0x90, 0x90, 0xF0, 0x10, 0x10, // 4
			0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
			0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
			0xF0, 0x10, 0x20, 0x40, 0x40, // 7
			0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
			0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
			0xF0, 0x90, 0xF0, 0x90, 0x90, // A
			0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
			0xF0, 0x80, 0x80, 0x80, 0xF0, // C
			0xE0, 0x90, 0x90, 0x90, 0xE0, // D
			0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
			0xF0, 0x80, 0xF0, 0x80, 0x80  // F
		];
		
		/**
		*	Constructor
		*/
		public function Flip ()
		{
			var i:uint;
			
			_timer = new Timer(_period,1);
			
			_buffer = new BitmapData(64,32,false,0xFF000000);
			
			// Only create instances once to save memory
			_memory = new Vector.<uint>(4096,true);
			V = new Vector.<uint>(16,true);
			_stack = new Vector.<uint>(16,true);
			_vram = new Vector.<Boolean>(2048,true);
			_key = new Vector.<Boolean>(16,true);
			
			super(_buffer);
		}
		
		/**
		*	Initializes the machine
		*/
		private function init () : void
		{
			_drawFlag = false;
			_curCycle = 0;
			
			_pc		= 0x200;	// Program counter begins at 0x200
			_opcode	= 0			// reset opcode
			I		= 0;		// reset register index
			_sp		= 0;		// reset stack pointer
			
			// Reset all machine memory
			_memory.forEach( setZero );
			V.forEach( setZero );
			_stack.forEach( setZero );
			_vram.forEach( setFalse );
			_key.forEach( setFalse );
			
			// Load fontset
			for(var i:uint = 0; i < 80; i++)
			{
				_memory[i] = _fontset[i];
			}
			
			_buffer.fillRect(_buffer.rect, 0xFF000000);
		}
		
		/**
		*	Emulator update function
		*/
		private function update ( e:TimerEvent ) : void
		{
			_beforeTime = getTimer();
			_overSleepTime = (_beforeTime - _afterTime) - _sleepTime;
			
			cycle();
			if(_drawFlag)
				draw();
			
			_afterTime = getTimer();
			_timeDiff = _afterTime - _beforeTime;
			_sleepTime = (_period - _timeDiff) - _overSleepTime;
			
			if(_sleepTime <= 0)
			{
				_excess -= _sleepTime;
				_sleepTime = 2;
			}
			
			_timer.reset();
			_timer.delay = _sleepTime;
			_timer.start();
			
			while(_excess > _period)
			{
				cycle();
				_excess -= _period;
			}
			
			//trace(_key);
		}
		
		/**
		*	Emulates one CPU cycle
		*/
		private function cycle () : void
		{
			_curCycle++;
			
			// Fetch opcode
			_opcode = _memory[ _pc ] << 8 | _memory[ _pc + 1 ];
			_pc += 2;
			
			// Execute opcode
			_instructionTable[ _opcode >> 12 ]();
			
			// Update timers
			if(_delayTimer > 0)
				_delayTimer--;
			if(_soundTimer > 0)
				_soundTimer--;
		}
		
		/**
		*	Loads a Chip-8 program into memory
		*/
		public function load ( program:Class ) : void
		{
			init();
			
			var data : ByteArray = new program();
			data.position = 0;
			
			// Copy program to memory
			while(data.bytesAvailable)
			{
				_memory[ data.position + 512 ] = data.readUnsignedByte();	// Programs begin at 0x200 (512)
			}
			
			// Run the program
			start();
		}
		
		/**
		*	Starts the emulator
		*/
		public function start () : void
		{
			_timer.addEventListener(TimerEvent.TIMER, update);
			_timer.start();
		}
		
		/**
		*	Stops the emulator
		*/
		public function stop () : void
		{
			_timer.removeEventListener(TimerEvent.TIMER, update);
			_timer.stop();
		}
		
		/**
		*	Sets the pressed key to true
		*/
		public function pressKey ( keyCode : uint ) : void
		{
			if(keyCode < 16)
				_key[keyCode] = true;
		}
		
		/**
		*	Sets the pressed key to false
		*/
		public function releaseKey ( keyCode : uint ) : void
		{
			if(keyCode < 16)
				_key[keyCode] = false;
		}
		
		/**
		*	Draws the VRAM to the buffer
		*/
		private function draw () : void
		{
			// Clear buffer
			_buffer.fillRect(_buffer.rect,0xFF000000);
			for(var i:uint = 0; i < _vram.length; i++)
			{
				if(_vram[i])
					_buffer.setPixel(i % 64, i / 64, 0xFFFFFFFF);
					
			}
			_drawFlag = false;
		}
		
		/**
		*	Simply clears the VRAM
		*/
		private function clearVRAM () : void
		{
			_vram.forEach( setFalse );
		}
		
		/**
		*	A callback function used for
		*	clearing/resetting vectors
		*/
		private function setZero ( item:uint, index:int, vector:Vector.<uint> ) : void
		{
			vector[index] = 0;
		}
		
		/**
		*	A callback function used for
		*	clearing/resetting vectors
		*/
		private function setFalse ( item:uint, index:int, vector:Vector.<Boolean> ) : void
		{
			vector[index] = false;
		}
		
		//////////////////////////////////////////////////////////////////////////////////////////////
		//
		//			CPU specific instructions
		//
		//////////////////////////////////////////////////////////////////////////////////////////////
		
		/**
		*	Instruction table that references the CPU instruction functions
		*/
		private const _instructionTable : Array = 
		[
		 cpuSpecial,	cpuJump,	cpuCallSub,	cpuSkipEq,	cpuSkipNeq,	cpuSkipEqReg,	cpuSetReg,	cpuAddReg,
		 cpuArithmetic,	cpuSkipNeqReg,	cpuSetRegIndex,	cpuJumpReg,	cpuSetRand,	cpuDrawSprite,	cpuInput,	cpuMisc
		];
		
		/**
		*	Instruction table for arithmetic opcodes
		*/
		private const _arithmeticTable : Array =
		[
		 cpuSwitchReg,	cpuOrReg,	cpuAndReg,	cpuXorReg,	cpuAddRegCarry,	cpuSubRegCarry,	cpuShiftRegR,	cpuRevSubReg,
		 nop,	nop,	nop,	nop,	nop,	nop,	cpuShiftRegL,	nop
		];
		
		/**
		*	Instruction table for the first three "special" opcodes
		*/
		private const _specialTable : Array =
		[
		 clearVRAM,	nop,	nop,	nop,	nop,	nop,	nop,	nop,
		 nop,		nop,	nop,	nop,	nop,	nop,	cpuReturnSub,	nop
		];
		
		/**
		*	No operation
		*/
		private function nop () : void
		{
		}
		
		/**
		*	Handles the arithmetic operations
		*/
		private function cpuArithmetic () : void
		{
			_arithmeticTable[ _opcode & 0x000F ]();
		}
		
		/**
		*	Handles the first three "special" opcodes
		*/
		private function cpuSpecial () : void
		{
			_specialTable[ _opcode & 0x000F ]();
		}
		
		/**
		*	0x00EE
		*	Return from a subroutine
		*/
		private function cpuReturnSub () : void
		{
			_pc = _stack[ _sp - 1 ];	// Set program counter back to saved position
		}
		
		/**
		*	0x1NNN
		*	Jump to adress 0x0NNN
		*/
		private function cpuJump () : void
		{
			_pc = _opcode & 0x0FFF;
		}
		
		/**
		*	0x2NNN
		*	Calls a subroutine NNN
		*/
		private function cpuCallSub () : void
		{
			_stack[ _sp ] = _pc;	// Save current program counter
			_sp++;					// Increase so we don't overwrite the stack
			_sp %= 16;
			_pc = _opcode & 0x0FFF;	// Set the program counter to subroutine adress
		}
		
		/**
		*	0x3XNN
		*	Skip the next instruction if VX equals NN
		*/
		private function cpuSkipEq () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] == (_opcode & 0x00FF) )
				_pc += 2;
		}
		
		/**
		*	0x4XNN
		*	Skip the next instruction if VX doesn't equal NN
		*/
		private function cpuSkipNeq () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] != (_opcode & 0x00FF) )
				_pc += 2;
		}
		
		/**
		*	0x5XY0
		*	Skip the next instruction if VX equals VY
		*/
		private function cpuSkipEqReg () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] == V[ (_opcode & 0x00F0) >> 4 ] )
				_pc += 2;
		}
		
		/**
		*	0x6XNN
		*	Set VX to NN
		*/
		private function cpuSetReg () : void
		{
			V[ (_opcode & 0x0F00) >> 8 ] = _opcode & 0x00FF;
		}
		
		/**
		*	0x7XNN
		*	Add NN to VX
		*/
		private function cpuAddReg () : void
		{
			V[ (_opcode & 0x0F00) >> 8 ] += _opcode & 0x00FF;
			V[ (_opcode & 0x0F00) >> 8 ] %= 256;	// To keep it true to the byte yo
		}
		
		/**
		*	0x8XY0
		*	Set VX to value of VY
		*/
		private function cpuSwitchReg () : void
		{
			V[(_opcode & 0x0F00) >> 8] = V[(_opcode & 0x00F0) >> 4];
		}
		
		/**
		*	0x8XY1
		*	Set VX to value of VX or VY
		*/
		private function cpuOrReg () : void
		{
			V[(_opcode & 0x0F00) >> 8] = V[(_opcode & 0x0F00) >> 8] | V[(_opcode & 0x00F0) >> 4];
		}
		
		/**
		*	0x8XY2
		*	Set VX to value of VX and VY
		*/
		private function cpuAndReg () : void
		{
			V[(_opcode & 0x0F00) >> 8] = V[(_opcode & 0x0F00) >> 8] & V[(_opcode & 0x00F0) >> 4];
		}
		
		/**
		*	0x8XY3
		*	Set VX to value of VX xor VY
		*/
		private function cpuXorReg () : void
		{
			V[(_opcode & 0x0F00) >> 8] = V[(_opcode & 0x0F00) >> 8] ^ V[(_opcode & 0x00F0) >> 4];
		}
		
		/**
		*	0x8XY4
		*	Adds VX to VY. If the result is above 256, VF is set to 1, otherwise 0
		*/
		private function cpuAddRegCarry () : void
		{
			V[0xF] = 0;
			V[(_opcode & 0x0F00) >> 8] += V[(_opcode & 0x00F0) >> 4];
			if( V[(_opcode & 0x0F00) >> 8] >= 256 )
			{
				V[(_opcode & 0x0F00) >> 8] %= 256;
				V[0xF] = 1;
			}
		}
		
		/**
		*	0x8XY5
		*	Subtract VY from VX. VF is 0 if there is a borrow, else 1
		*/
		private function cpuSubRegCarry () : void
		{
			V[0xF] = 1;
			V[(_opcode & 0x0F00) >> 8] -= V[(_opcode & 0x00F0) >> 4];
			if( V[(_opcode & 0x0F00) >> 8] >= 256 )
			{
				V[(_opcode & 0x0F00) >> 8] %= 256;
				V[0xF] = 0;
			}
		}
		
		/**
		*	0x8X06
		*	Shift VX by one. Set VF to least significant bit before shift
		*/
		private function cpuShiftRegR () : void
		{
			V[0xF] = V[(_opcode & 0x0F00) >> 8] & 0x000F;
			V[(_opcode & 0x0F00) >> 8] = V[(_opcode & 0x0F00) >> 8] >> 1;
		}
		
		/**
		*	0x8XY7
		*	Sets VX to VY minus VX. VF is set to 0 when there's a borrow, and 1 when there isn't.
		*/
		private function cpuRevSubReg () : void
		{
			V[0xF] = 1;
			V[(_opcode & 0x0F00) >> 8] = V[(_opcode & 0x00F0) >> 4] - V[(_opcode & 0x0F00) >> 8];
			if( V[(_opcode & 0x0F00) >> 8] >= 256 )
			{
				V[(_opcode & 0x0F00) >> 8] %= 256;
				V[0xF] = 0;
			}
		}
		
		/**
		*	0x8X0E
		*	Shift VX left by one. Set VF to most significant bit before shift
		*/
		private function cpuShiftRegL () : void
		{
			V[0xF] = (V[(_opcode & 0x0F00) >> 8] & 0xF000) >> 12;
			V[(_opcode & 0x0F00) >> 8] = ( V[(_opcode & 0x0F00) >> 8] << 1 ) & 0xFFFF;
		}
		
		/**
		*	0x9XY0
		*	Skip the next instruction if VX doesn't equal VY
		*/
		private function cpuSkipNeqReg () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] != V[ (_opcode & 0x00F0) >> 4 ] )
				_pc += 2;
		}
		
		/**
		*	0xANNN
		*	Sets the register index I to NNN
		*/
		private function cpuSetRegIndex () : void
		{
			I = _opcode & 0x0FFF;
		}
		
		/**
		*	0xBNNN
		*	Jumps to the adress NNN plus V0
		*/
		private function cpuJumpReg () : void
		{
			_pc = ( (_opcode & 0x0FFF) + V[0] ) % 256;
		}
		
		/**
		*	0xCXNN
		*	Sets VX to a random number plus NN
		*/
		private function cpuSetRand () : void
		{
			V[(_opcode & 0x0F00) >> 8] = (( Math.random() * 255 ) + (_opcode & 0x00FF)) % 256;
		}
		
		/**
		*	0xDXYN
		*	Draws a sprite at (X,Y) that is N pixels high
		*/
		private function cpuDrawSprite () : void
		{
			var x : uint = V[(_opcode & 0x0F00) >> 8] % 256;
			var y : uint = V[(_opcode & 0x00F0) >> 4] % 256;
			var h : uint = _opcode & 0x000F;
			var p : uint;
			
			V[0xF] = 0;
			for(var yl:uint = 0; yl < h; yl++)
			{
				p = _memory[ I + yl ];	// Fetch the first row of the sprite
				for(var xl:uint = 0; xl < 8; xl++)
				{
					if(x <= 64 && y <= 32)	// Ugly bug fix for now
					{
						if( (p & (0x80 >> xl)) != 0)	// If this pixel is set to 1
						{
							if( _vram[ (x + xl) + ((y + yl) * 64) ] == 1 )	// Collision detection
								V[0xF] = 1;
							_vram[ (x + xl) + ((y + yl) * 64) ] = !_vram[ (x + xl) + ((y + yl) * 64) ];	// Flip the pixel
						}
					}
				}
			}
			
			_drawFlag = true;
		}
		
		/**
		*	0xE0XX
		*	Handles input logic
		*/
		private function cpuInput () : void
		{
			switch( _opcode & 0x00FF )
			{
				case 0x9E:
					if( _key[ V[(_opcode & 0x0F00) >> 8] ] )	// If the key stored in VX is pressed
						_pc += 2;
					break;
				case 0xA1:
					if( !_key[ V[(_opcode & 0x0F00) >> 8] ] )	// If the key stored in VX isn't pressed
						_pc += 2;
					break;
			}
		}
		
		/**
		*	0xF000
		*	Miscellaneous but important CPU operations
		*/
		private function cpuMisc () : void
		{
			switch( _opcode & 0x00FF )
			{
				case 0x07:	// Sets VX to the value of the delay timer
					V[(_opcode & 0x0F00) >> 8] = _delayTimer;
					break;
				case 0x15:	// Sets the delay timer to VX
					_delayTimer = V[(_opcode & 0x0F00) >> 8];
					break;
				case 0x18:	// Sets the sound timer to VX
					_soundTimer = V[(_opcode & 0x0F00) >> 8];
					break;
				case 0x1E:	// Add VX to I
					I += V[(_opcode & 0x0F00) >> 8];
					I %= 256;
					break;
				case 0x55:	// Copies V0 to VX to memory starting at adress I
					for(var i:uint = 0; i < (_opcode & 0x0F00) >> 8; i++)
					{
						_memory[I + i] = V[i];
					}
					break;
				case 0x65:	// Fills V0 to VX with values from memory starting at address I
					for(var i:uint = 0; i < (_opcode & 0x0F00) >> 8; i++)
					{
						V[i] = _memory[I + i];
					}
					break;
				default:
					break;
			}
		}
		
	}	// End Class
}	// End Package