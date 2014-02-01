﻿package flip
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
		private const FRAME_RATE : uint	= 1;
		private var _period : Number = 1000 / FRAME_RATE;
		private var _beforeTime : int;
		private var _afterTime : int;
		private var _timeDiff : int;
		private var _sleepTime : uint;
		private var _overSleepTime : uint;
		private var _excess : uint;
		
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
			
			super(_buffer);
		}
		
		/**
		*	Initializes the machine
		*/
		private function init () : void
		{
			_drawFlag = false;
			_pc		= 0x200;	// Program counter begins at 0x200
			_opcode	= 0			// reset opcode
			I		= 0;		// reset register index
			_sp		= 0;		// reset stack pointer
			
			// Reset all machine memory
			_memory.forEach( setZero );
			V.forEach( setZero );
			_stack.forEach( setZero );
			_vram.forEach( setFalse );
			
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
		}
		
		/**
		*	Emulates one CPU cycle
		*/
		private function cycle () : void
		{
			// Fetch opcode
			_opcode = _memory[ _pc ] << 8 | _memory[ _pc + 1 ];
			_pc += 2;
			
			trace(_opcode.toString(16));
			
			// Execute opcode
			_instructionTable[ _opcode >> 12 ]();
		}
		
		/**
		*	Loads a Chip-8 program into memory
		*/
		public function load ( program:Class ) : void
		{
			init();
			
			var data : ByteArray = new program();
			data.endian = Endian.BIG_ENDIAN;
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
		 cpuArithmetic,	cpuSkipNeqReg,	cpuSetRegIndex,	cpuJumpReg,	nop,	cpuDrawSprite,	nop,	nop
		];
		
		/**
		*	Instruction table for arithmetic opcodes
		*/
		private const _arithmeticTable : Array =
		[
		 nop,	nop,	nop,	nop,	nop,	nop,	nop,	nop,
		 nop,	nop,	nop,	nop,	nop,	nop,	nop,	nop
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
			_pc = _stack[ _sp-- ];	// Set program counter back to saved position
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
			_pc = _opcode & 0x0FFF;	// Set the program counter to subroutine adress
		}
		
		/**
		*	0x3XNN
		*	Skip the next instruction if VX equals NN
		*/
		private function cpuSkipEq () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] == (_opcode & 0x00FF) )
				_pc += 4;
		}
		
		/**
		*	0x4XNN
		*	Skip the next instruction if VX doesn't equal NN
		*/
		private function cpuSkipNeq () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] != (_opcode & 0x00FF) )
				_pc += 4;
		}
		
		/**
		*	0x5XY0
		*	Skip the next instruction if VX equals VY
		*/
		private function cpuSkipEqReg () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] == V[ (_opcode & 0x00F0) >> 4 ] )
				_pc += 4;
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
		*	0x9XY0
		*	Skip the next instruction if VX doesn't equal VY
		*/
		private function cpuSkipNeqReg () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] != V[ (_opcode & 0x00F0) >> 4 ] )
				_pc += 4;
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
		*	0xDXYN
		*	Draws a sprite at (X,Y) that is N pixels high
		*/
		private function cpuDrawSprite () : void
		{
			var x : uint = V[(_opcode & 0x0F00) >> 8];
			var y : uint = V[(_opcode & 0x00F0) >> 4];
			var h : uint = _opcode & 0x000F;
			var p : uint;
			
			V[0xF] = 0;
			for(var yl:uint = 0; yl < h; yl++)
			{
				p = _memory[ I + yl ];	// Fetch the first row of the sprite
				for(var xl:uint = 0; xl < 8; xl++)
				{
					if( (p & (0x80 >> xl)) != 0)	// If this pixel is set to 1
					{
						if( _vram[ (x + xl) + ((y + yl) * 64) ] == 1 )	// Collision detection
							V[0xF] = 1;
						_vram[ (x + xl) + ((y + yl) * 64) ] != _vram[ (x + xl) + ((y + yl) * 64) ];	// Flip the pixel
					}
				}
			}
			
			_drawFlag = true;
		}
	}
}