package flip
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	import flash.utils.Endian;
	import flash.events.TimerEvent;
	import flip.filters.IFlFilter;
	import flip.keymap.*;
	import flash.geom.Point;
	import flip.debug.FlipDebugger;
	import flash.media.Sound;
	
	public class Flip extends Bitmap
	{
		[Embed(source="../assets/INVADERS",mimeType="application/octet-stream")]
		public static var DEFAULT_APP : Class;
		[Embed(source="../assets/blip.mp3")]
		private const BLIP:Class;
		
		public static const STATE_RUNNING : uint = 0;
		public static const STATE_HALTED : uint = 1;
		
		public static const MODE_LEGACY : uint	= 0;
		public static const MODE_SUPER : uint	= 1;
		public static const MODE_HIRES : uint	= 2;
		
		public static const BG_COLOR : int = 0xFF0F380F;
		public static const FG_COLOR : int = 0xFF9BBC0F;
		
		public static const KEY_0 : uint = 0;
		public static const KEY_1 : uint = 1;
		public static const KEY_2 : uint = 2;
		public static const KEY_3 : uint = 3;
		public static const KEY_4 : uint = 4;
		public static const KEY_5 : uint = 5;
		public static const KEY_6 : uint = 6;
		public static const KEY_7 : uint = 7;
		public static const KEY_8 : uint = 8;
		public static const KEY_9 : uint = 9;
		public static const KEY_A : uint = 10;
		public static const KEY_B : uint = 11;
		public static const KEY_C : uint = 12;
		public static const KEY_D : uint = 13;
		public static const KEY_E : uint = 14;
		public static const KEY_F : uint = 15;
		
		/**
		*	User definable callback function
		*	Called when the screen size changes
		*/
		public var resizeCallback : Function;
		
		/**
		*	Screen buffer
		*/
		private var _screen : BitmapData;
		/**
		*	Previous frame buffer
		*/
		private var _buffer : BitmapData;
		/**
		*	Tells wether to update the screen
		*/
		private var _drawFlag : Boolean;
		/**
		*	Contains all screen filters
		*/
		private var _filters : Vector.<IFlFilter>;
		/**
		*	Copy of program data used when resetting machine
		*/
		private var _programData : ByteArray;
		/**
		*	Current emulation mode
		*/
		private var _emumode : uint;
		/**
		*	Current CPU state
		*/
		private var _state : uint;
		/**
		*	Blip sound reference
		*/
		private var _blip : Sound;
		/**
		*	Used to keep the machine running at a constant speed
		*/
		private var _timer : Timer;
		private const FRAME_RATE : uint	= 60;
		private var _period : Number = 1000 / FRAME_RATE;
		private var _beforeTime : int;
		private var _afterTime : int;
		private var _timeDiff : int;
		private var _sleepTime : uint;
		private var _overSleepTime : uint;
		private var _excess : uint;
		
		/**
		*	Simple but very useful debugger
		*/
		private var _debugger : FlipDebugger;
		
		/////////////////////////////////////////////////////////////////////// Machine related variables
		
		/**
		*	Machine speed, i.e. machine runs at SPEED x normal operation
		*/
		public var speed : uint = 5;
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
		*	HP48 calculator flags/memory
		*	Used in SCHIP mode
		*/
		private var _hpFlags : Vector.<uint>;
		/**
		*	Index register
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
		*	Handles input and key remapping
		*/
		private var _keymap : KeyMap;
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
		*	Font table for the SuperChip-8 fontset
		*/
		private const _superfont : Array =
		[
			0x3C, 0x66, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0x66, 0x3C, // 0
			0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, // 1
			0x7E, 0xC3, 0xC3, 0x03, 0x1E, 0x60, 0xC0, 0xC0, 0xC3, 0xFF, // 2
			0x7E, 0xC3, 0xC3, 0x03, 0x3E, 0x03, 0x03, 0xC3, 0xC3, 0x7E, // 3
			0x06, 0x0E, 0x1E, 0x36, 0x66, 0xC6, 0xFF, 0x06, 0x06, 0x0F, // 4
			0xFF, 0xC0, 0xC0, 0xC0, 0xFE, 0x03, 0x03, 0xC3, 0xC3, 0x7E, // 5
			0x1C, 0x30, 0x60, 0x60, 0xFE, 0xC3, 0xC3, 0xC3, 0xC3, 0x7E, // 6
			0xFF, 0x03, 0x06, 0x06, 0x0C, 0x0C, 0x18, 0x18, 0x30, 0x30, // 7
			0x7E, 0xC3, 0xC3, 0xC3, 0x7E, 0xC3, 0xC3, 0xC3, 0xC3, 0x7E, // 8
			0x7E, 0xC3, 0xC3, 0xC3, 0xC3, 0x7F, 0x06, 0x06, 0x0C, 0x78, // 9
			0x18, 0x3C, 0x2C, 0x2C, 0x46, 0x46, 0x7E, 0x83, 0x83, 0xC7, // A
			0xFC, 0x66, 0x66, 0x66, 0x7C, 0x66, 0x63, 0x63, 0x63, 0xFE, // B
			0x3F, 0x63, 0xC1, 0xC0, 0xC0, 0xC0, 0xC0, 0xC1, 0x63, 0x3E, // C
			0xFC, 0x66, 0x63, 0x63, 0x63, 0x63, 0x63, 0x63, 0x66, 0xFC, // D
			0xFF, 0x63, 0x61, 0x60, 0x7C, 0x60, 0x60, 0x61, 0x63, 0xFF, // E
			0xFF, 0x63, 0x61, 0x60, 0x7C, 0x60, 0x60, 0x60, 0x60, 0xF0  // F
		];
		
		/**
		*	Constructor
		*/
		public function Flip ()
		{
			_blip = new BLIP();
			_state = STATE_HALTED;
			
			_timer = new Timer(_period,1);
			_filters = new Vector.<IFlFilter>();
			
			// Only create instances once to save memory
			_programData = new ByteArray();
			_memory = new Vector.<uint>(4096,true);
			V = new Vector.<uint>(16,true);
			_hpFlags = new Vector.<uint>(8,true);
			_stack = new Vector.<uint>(16,true);
			_keymap = new KeyMap();
			
			_debugger = new FlipDebugger();
			_debugger.setRegistry(V);
			
			// init rest of machine
			init();
			
			super(_screen);
		}
		
		/**
		*	Sets the machine for legacy CHIP-8 support
		*/
		private function setSupportLegacy () : void
		{
			_emumode = MODE_LEGACY;
			
			_screen = new BitmapData(64,32,false,BG_COLOR);
			_buffer = new BitmapData(64,32,false,BG_COLOR);
			_vram = new Vector.<Boolean>(64 * 32,true);
			_vram.forEach( setFalse );
			
			this.bitmapData = _screen;
			
			if(resizeCallback != null)
				resizeCallback();
				
			log("legacy mode");
		}
		
		/**
		*	Sets the machine for legacy CHIP-8 hires support
		*/
		private function setSupportHires () : void
		{
			_emumode = MODE_HIRES;
			
			_screen = new BitmapData(64,64,false,BG_COLOR);
			_buffer = new BitmapData(64,64,false,BG_COLOR);
			_vram = new Vector.<Boolean>(64 * 64,true);
			_vram.forEach( setFalse );
			
			this.bitmapData = _screen;
			
			if(resizeCallback != null)
				resizeCallback();
			
			log("hires mode");
		}
		
		/**
		*	Sets the machine for Super CHIP-8 support
		*/
		private function setSupportSuper () : void
		{
			_emumode = MODE_SUPER;
			
			_screen = new BitmapData(128,64,false,BG_COLOR);
			_buffer = new BitmapData(128,64,false,BG_COLOR);
			_vram = new Vector.<Boolean>(128 * 64,true);
			_vram.forEach( setFalse );
			
			this.bitmapData = _screen;
			
			if(resizeCallback !=null)
				resizeCallback();
				
			log("super mode");
		}
		
		/**
		*	Initializes the machine
		*/
		private function init () : void
		{
			_drawFlag = false;
			
			_pc		= 0x200;	// Program counter begins at 0x200
			_opcode	= 0			// reset opcode
			I		= 0;		// reset index register
			_sp		= 0;		// reset stack pointer
			
			// Always call in case legacy programs
			// don't utilize the 0x00FE instruction
			setSupportLegacy();
			
			// Reset all machine memory
			_memory.forEach( setZero );
			V.forEach( setZero );
			_hpFlags.forEach( setZero );
			_stack.forEach( setZero );
			_vram.forEach( setFalse );
			_keymap.reset();
			
			_delayTimer = _soundTimer = 0;
			
			// Load fontset
			for(var i:uint = 0; i < _fontset.length; i++)
			{
				_memory[i] = _fontset[i];
			}
			
			// Load SCHIP fontset
			for(i = 0; i < _superfont.length; i++)
			{
				_memory[i + 0x50] = _superfont[i];
			}
			
			_buffer.fillRect(_buffer.rect, BG_COLOR);
			_screen.fillRect(_screen.rect, BG_COLOR);
		}
		
		/**
		*	Emulator update function
		*/
		private function update ( e:TimerEvent ) : void
		{
			_beforeTime = getTimer();
			_overSleepTime = (_beforeTime - _afterTime) - _sleepTime;
			
			for(var i:uint = 0; i < speed; i++)
			{
				cycle();
			}
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
			_opcode = _memory[ _pc ] << 8 | _memory[ _pc + 1 ];	// Fetch opcode
				
			if(_pc == 0x200 && _opcode == 0x1260)	// Catch HIRES mode
			{
				setSupportHires();
				_opcode = 0x12C0;	// Jump to 0x2C0
			}
			
			_pc += 2;
			_pc %= 4096;
			
			// Execute opcode
			_instructionTable[ _opcode >> 12 ]();
			
			if(_soundTimer == 1)
				_blip.play();
			
			// Update timers
			if(_delayTimer > 0)
				_delayTimer--;
			if(_soundTimer > 0)
				_soundTimer--;
		}
		
		/**
		*	Draws the VRAM to the buffer
		*/
		private function draw () : void
		{
			_screen.lock();
			
			var i:uint;
			// Copy this screen to back buffer
			_buffer.copyPixels(_screen,_screen.rect,new Point(0,0));
			
			// Clear screen
			_screen.fillRect(_screen.rect,BG_COLOR);
			// Draw from VRAM
			for(i = 0; i < _vram.length; i++)
			{
				if(_vram[i])
					_screen.setPixel(i % _screen.width, i / _screen.width, FG_COLOR);
					
			}
			
			// Update filters if any
			for(i = 0; i < _filters.length; i++)
			{
				_filters[i].render(_screen,_buffer);
			}
			
			_screen.unlock();
			_drawFlag = false;
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
		private function setFalse ( item:Boolean, index:int, vector:Vector.<Boolean> ) : void
		{
			vector[index] = false;
		}
		
		private function bytify ( item:uint, index:int, vector:Vector.<uint> ) : void
		{
			vector[index] %= 256;
		}
		
		private function traceVector ( item:uint, index:int, vector:Vector.<uint> ) : void
		{
			trace(index, index.toString(16), item.toString(16));
		}
		
		/**
		*	Properly logs a message to the debugger
		*/
		private function log ( msg:String ) : void
		{
			// Compensate program counter for the emulator flow of operation
			_debugger.log(_pc,I,_opcode,msg);
		}
		
		/**
		*	Custo modulo function that wraps negatives
		*/
		private function mod ( x:int, m:int ) : int
		{
			var r:int = x%m;
			return (r<0) ? r+m : r;
		}
		
		/**
		*	Loads a Chip-8 program into memory
		*/
		public function load ( program:ByteArray, autoPlay : Boolean = true ) : void
		{
			init();
			
			program.position = 0;
			
			// Copy program to memory
			while(program.bytesAvailable)
			{
				_memory[ program.position + 0x200 ] = program.readUnsignedByte();	// Programs begin at 0x200 (512)
			}
			
			_programData.position = 0;
			_programData.writeBytes(program);	// Copy program data for future use
			
			// Run the program
			if(autoPlay && _state == STATE_RUNNING)
				run();
		}
		
		/**
		*	Starts/resumes the emulator
		*/
		public function run () : void
		{
			_state = STATE_RUNNING;
			_timer.addEventListener(TimerEvent.TIMER, update);
			_timer.start();
		}
		
		/**
		*	Stops the emulator
		*/
		public function halt () : void
		{
			_state = STATE_HALTED;
			_timer.removeEventListener(TimerEvent.TIMER, update);
			_timer.stop();
		}
		
		/**
		*	Step the emulator one cycle forward
		*/
		public function step () : void
		{
			cycle();
			
			if(_drawFlag)
				draw();
		}
		
		/**
		*	Resets the emulator
		*/
		public function reset () : void
		{
			load(_programData);
		}
		
		/**
		*	Adds a filter to the filter stack
		*/
		public function addFilter ( filter : IFlFilter ) : void
		{
			_filters.push( filter );
		}
		
		/**
		*	Sets the keymap to the provided keymap
		*/
		public function set keymap ( k:KeyMap ) : void
		{
			_keymap = k;
		}
		
		/**
		*	Returns a reference to the internal keymap
		*	so that Flip can listen for external key presses
		*	via KeyMap.pressKey() and KeyMap.releaseKey()
		*/
		public function get keys () : KeyMap
		{
			return _keymap;
		}
		
		/**
		*	Return the current emulation mode
		*/
		public function get mode () : uint
		{
			return _emumode;
		}
		
		/**
		*	Return the actual width of the screen
		*/
		public function get screenWidth () : int
		{
			return _screen.width;
		}
		
		/**
		*	Return the actual height of the screen
		*/
		public function get screenHeight () : int
		{
			return _screen.height;
		}
		
		/**
		*	Returns a copy of the debugger
		*/
		public function get debugger () : FlipDebugger
		{
			return _debugger;
		}
		
		/**
		*	Returns the CPU state
		*/
		public function get state () : uint
		{
			return _state;
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
		*	Instruction table for the 0x00X0 opcodes
		*/
		private const _specialTable : Array =
		[
		 nop,	nop,	nop,	cpuClearVRAM,	nop,	nop,	nop,	nop,
		 nop,	nop,	nop,	nop,	cpuScrollVRAMDown,	nop,	cpuSpecialE,	cpuSpecialF
		];
		
		/**
		*	Instruction table for the 0x00FX opcodes
		*/
		private const _specialFTable : Array =
		[
		 nop,	nop,	nop,	nop,	nop,	nop,	nop,	nop,
		 nop,	nop,	nop,	cpuScrollVRAMRight,	cpuScrollVRAMLeft,	reset,	setSupportLegacy,	setSupportSuper
		];
		
		/**
		*	Instruction table for the 0x00EX opcodes
		*/
		private const _specialETable : Array =
		[
		 cpuClearVRAM,	nop,	nop,	nop,	nop,	nop,	nop,	nop,
		 nop,	nop,	nop,	nop,	nop,	nop,	cpuReturnSub,	nop
		];
		
		/**
		*	No operation
		*/
		private function nop () : void
		{
			log("NOP");
		}
		
		/**
		*	Handles the arithmetic operations
		*/
		private function cpuArithmetic () : void
		{
			_arithmeticTable[ _opcode & 0x000F ]();
		}
		
		/**
		*	Handles the 0x00X0 opcodes
		*/
		private function cpuSpecial () : void
		{
			_specialTable[ (_opcode & 0x00F0) >> 4 ]();
		}
		
		/**
		*	Handles the 0x00FX opcodes
		*/
		private function cpuSpecialF () : void
		{
			_specialFTable[ _opcode & 0x000F ]();
		}
		
		/**
		*	Handles the 0x00EX opcodes
		*/
		private function cpuSpecialE () : void
		{
			_specialETable[ _opcode & 0x000F ]();
		}
		
		/**
		*	0x00CN
		*	Scroll VRAM down N lines
		*/
		private function cpuScrollVRAMDown () : void
		{
			// copy current vram
			var c:Vector.<Boolean> = _vram.slice();
			// Scroll amount
			var a:uint = _opcode & 0x000F;
			
			var i:int = _vram.length - 1;
			while(i > _screen.width * a)
			{
				_vram[i] = c[ i - (_screen.width * a) ];
				i--;
			}
			while(i >= 0)
			{
				_vram[i] = false;
				i--;
			}
			
			_drawFlag = true;
			
			log("scroll VRAM down by " + a);
		}
		
		/**
		*	0x00FB
		*	Scroll VRAM right one pixel
		*/
		private function cpuScrollVRAMRight () : void
		{
			// copy current vram
			var c:Vector.<Boolean> = _vram.slice();
			
			var i:int = _vram.length - 1;	// Begin at end of VRAM
			while(i >= 0)
			{
				if(i % _screen.width > 3)
				{
					_vram[i] = c[i-4];
				}
				else
				{
					_vram[i] = false;
				}
				
				i--;
			}
			
			/*for(var y:uint = 0; y < _screen.height; y++)
			{
				for(var x:uint = 0; x < _screen.width; x++)
				{
					_vram[x + (y * _screen.width)] = c[ mod(x - 4, _screen.width ) + ( y * _screen.width) ];
				}
			}*/
			
			_drawFlag = true;
			
			log("scroll VRAM right");
		}
		
		/**
		*	0x00FC
		*	Scroll VRAM left 4 pixels
		*/
		private function cpuScrollVRAMLeft () : void
		{
			// copy current vram
			var c:Vector.<Boolean> = _vram.slice();
			
			var i:int = 0;
			var eol:int = _screen.width - 4;
			while(i < _vram.length)
			{
				if(i % _screen.width >= eol)
				{
					_vram[i] = false;
				}
				else
				{
					_vram[i] = c[i+4];
				}
				i++;
			}
			
			/*for(var y:uint = 0; y < _screen.height; y++)
			{
				for(var x:uint = 0; x < _screen.width; x++)
				{
					_vram[x + (y * _screen.width)] = c[ ((x + 4) % _screen.width ) + ( y * _screen.width) ];
				}
			}*/
			
			_drawFlag = true;
			
			log("scroll VRAM left");
		}
		
		/**
		*	0x00E0
		*	Clears the VRAM
		*/
		private function cpuClearVRAM () : void
		{
			_vram.forEach( setFalse );
			log("clear VRAM");
		}
		
		/**
		*	0x00EE
		*	Return from a subroutine
		*/
		private function cpuReturnSub () : void
		{
			_sp--;
			_sp %= 16;
			_pc = _stack[ _sp ];	// Set program counter back to saved position
			
			log("return from sub to " + _pc.toString(16));
		}
		
		/**
		*	0x1NNN
		*	Jump to adress 0x0NNN
		*/
		private function cpuJump () : void
		{
			_pc = _opcode & 0x0FFF;
			
			log("jump to " + _pc.toString(16));
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
			
			log("call sub " + _pc.toString(16));
		}
		
		/**
		*	0x3XNN
		*	Skip the next instruction if VX equals NN
		*/
		private function cpuSkipEq () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] == (_opcode & 0x00FF) )
				_pc += 2;
			
			log("skip if V"+((_opcode & 0x0F00) >> 8).toString(16)+" eq " + (_opcode & 0x00FF).toString(16) + " = " + ( V[ (_opcode & 0x0F00) >> 8 ] == (_opcode & 0x00FF) ));
		}
		
		/**
		*	0x4XNN
		*	Skip the next instruction if VX doesn't equal NN
		*/
		private function cpuSkipNeq () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] != (_opcode & 0x00FF) )
				_pc += 2;
			
			log("skip if V"+((_opcode & 0x0F00) >> 8).toString(16)+" neq " + (_opcode & 0x00FF).toString(16) + " = " + ( V[ (_opcode & 0x0F00) >> 8 ] != (_opcode & 0x00FF) ));
		}
		
		/**
		*	0x5XY0
		*	Skip the next instruction if VX equals VY
		*/
		private function cpuSkipEqReg () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] == V[ (_opcode & 0x00F0) >> 4 ] )
				_pc += 2;
			
			log("skip if V"+((_opcode & 0x0F00) >> 8).toString(16)+" eq V" + ((_opcode & 0x00F0) >> 4).toString(16) + " = " + ( V[ (_opcode & 0x0F00) >> 8 ] == V[ (_opcode & 0x00F0) >> 4 ] ));
		}
		
		/**
		*	0x6XNN
		*	Set VX to NN
		*/
		private function cpuSetReg () : void
		{
			V[ (_opcode & 0x0F00) >> 8 ] = _opcode & 0x00FF;
			
			log("set V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = " + V[ (_opcode & 0x0F00) >> 8 ]);
		}
		
		/**
		*	0x7XNN
		*	Add NN to VX
		*/
		private function cpuAddReg () : void
		{
			V[ (_opcode & 0x0F00) >> 8 ] += _opcode & 0x00FF;
			V[ (_opcode & 0x0F00) >> 8 ] %= 256;
			
			log("add " + (_opcode & 0x00FF).toString(16) + " to V"+ ((_opcode & 0x0F00) >> 8).toString(16) +" = " + V[ (_opcode & 0x0F00) >> 8 ]);
		}
		
		/**
		*	0x8XY0
		*	Set VX to value of VY
		*/
		private function cpuSwitchReg () : void
		{
			V[(_opcode & 0x0F00) >> 8] = V[(_opcode & 0x00F0) >> 4];
			
			log("set V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = V" + ((_opcode & 0x00F0) >> 4).toString(16) + " = " + V[(_opcode & 0x0F00) >> 8]);
		}
		
		/**
		*	0x8XY1
		*	Set VX to value of VX or VY
		*/
		private function cpuOrReg () : void
		{
			V[(_opcode & 0x0F00) >> 8] |= V[(_opcode & 0x00F0) >> 4];
			V[(_opcode & 0x0F00) >> 8] %= 256;
			
			log("set V" + ((_opcode & 0x0F00) >> 8).toString(16) + " | V" + ((_opcode & 0x00F0) >> 4).toString(16) + " = " + V[(_opcode & 0x0F00) >> 8]);
		}
		
		/**
		*	0x8XY2
		*	Set VX to value of VX and VY
		*/
		private function cpuAndReg () : void
		{
			V[(_opcode & 0x0F00) >> 8] &= V[(_opcode & 0x00F0) >> 4];
			V[(_opcode & 0x0F00) >> 8] %= 256;
			
			log("set V" + ((_opcode & 0x0F00) >> 8).toString(16) + " & V" + ((_opcode & 0x00F0) >> 4).toString(16) + " = " + V[(_opcode & 0x0F00) >> 8]);
		}
		
		/**
		*	0x8XY3
		*	Set VX to value of VX xor VY
		*/
		private function cpuXorReg () : void
		{
			V[(_opcode & 0x0F00) >> 8] ^= V[(_opcode & 0x00F0) >> 4];
			V[(_opcode & 0x0F00) >> 8] %= 256;
			
			log("set V" + ((_opcode & 0x0F00) >> 8).toString(16) + " ^ V" + ((_opcode & 0x00F0) >> 4).toString(16) + " = " + V[(_opcode & 0x0F00) >> 8]);
		}
		
		/**
		*	0x8XY4
		*	Adds VY to VX. If the result is above 256, VF is set to 1, otherwise 0
		*/
		private function cpuAddRegCarry () : void
		{
			if( V[(_opcode & 0x00F0) >> 4] > (0xFF - V[(_opcode & 0x0F00) >> 8]) )
			{
				V[0xF] = 1; //carry
			}
			else 
			{
				V[0xF] = 0;		
			}
			V[(_opcode & 0x0F00) >> 8] += V[(_opcode & 0x00F0) >> 4];
			V[(_opcode & 0x0F00) >> 8] %= 256;
			
			log("V" + ((_opcode & 0x0F00) >> 8).toString(16) + " += V" + ((_opcode & 0x00F0) >> 4).toString(16) + " = " + V[(_opcode & 0x0F00) >> 8] + " : VF=" + V[0xF]);
		}
		
		/**
		*	0x8XY5
		*	Subtract VY from VX. VF is 0 if there is a borrow, else 1
		*/
		private function cpuSubRegCarry () : void
		{
			if( V[(_opcode & 0x00F0) >> 4] > V[(_opcode & 0x0F00) >> 8] )
			{
				V[0xF] = 0; //carry
			}
			else 
			{
				V[0xF] = 1;		
			}
			V[(_opcode & 0x0F00) >> 8] -= V[(_opcode & 0x00F0) >> 4];
			V[(_opcode & 0x0F00) >> 8] = mod(V[(_opcode & 0x0F00) >> 8], 256);
			
			log("V" + ((_opcode & 0x0F00) >> 8).toString(16) + " -= V" + ((_opcode & 0x00F0) >> 4).toString(16) + " = " + V[(_opcode & 0x0F00) >> 8] + " : VF=" + V[0xF]);
		}
		
		/**
		*	0x8X06
		*	Shift VX by one. Set VF to least significant bit before shift
		*/
		private function cpuShiftRegR () : void
		{
			V[0xF] = V[(_opcode & 0x0F00) >> 8] & 0x1;
			V[(_opcode & 0x0F00) >> 8] = V[(_opcode & 0x0F00) >> 8] >> 1;
			
			log("shift V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = " + V[(_opcode & 0x0F00) >> 8] + " : VF=" + V[0xF]);
		}
		
		/**
		*	0x8XY7
		*	Sets VX to VY minus VX. VF is set to 0 when there's a borrow, and 1 when there isn't.
		*/
		private function cpuRevSubReg () : void
		{
			if( V[(_opcode & 0x0F00) >> 8] > V[(_opcode & 0x00F0) >> 4] )
			{
				V[0xF] = 0;
			}
			else
			{
				V[0xF] = 1;
			}
			V[(_opcode & 0x0F00) >> 8] = V[(_opcode & 0x00F0) >> 4] - V[(_opcode & 0x0F00) >> 8];
			V[(_opcode & 0x0F00) >> 8] = mod( V[(_opcode & 0x0F00) >> 8], 256);
			
			log("set V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = V" + ((_opcode & 0x00F0) >> 4).toString(16) + " - V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = " + V[(_opcode & 0x0F00) >> 8] + " : VF=" + V[0xF]);
		}
		
		/**
		*	0x8X0E
		*	Shift VX left by one. Set VF to most significant bit before shift
		*/
		private function cpuShiftRegL () : void
		{
			V[0xF] = V[(_opcode & 0x0F00) >> 8] >> 7;
			V[(_opcode & 0x0F00) >> 8] = ( V[(_opcode & 0x0F00) >> 8] << 1 ) & 0xFFFF;
			
			log("shift left V" + ((_opcode & 0x0F00) >> 8).toString(16) + " MSB to VF=" + V[0xF]);
		}
		
		/**
		*	0x9XY0
		*	Skip the next instruction if VX doesn't equal VY
		*/
		private function cpuSkipNeqReg () : void
		{
			if( V[ (_opcode & 0x0F00) >> 8 ] != V[ (_opcode & 0x00F0) >> 4 ] )
				_pc += 2;
			
			log("skip if V" + ((_opcode & 0x0F00) >> 8).toString(16) + " neq V" + ((_opcode & 0x00F0) >> 4).toString(16) + " = " + (V[ (_opcode & 0x0F00) >> 8 ] != V[(_opcode & 0x00F0) >> 4]));
		}
		
		/**
		*	0xANNN
		*	Sets the register index I to NNN
		*/
		private function cpuSetRegIndex () : void
		{
			I = _opcode & 0x0FFF;
			
			log("set I = " + I.toString(16));
		}
		
		/**
		*	0xBNNN
		*	Jumps to the adress NNN plus V0
		*/
		private function cpuJumpReg () : void
		{
			_pc = (_opcode & 0x0FFF) + V[0];
			
			log("jump to " + (_opcode & 0x0FFF).toString(16) + " + V0 = " + _pc.toString(16));
		}
		
		/**
		*	0xCXNN
		*	Sets VX to a random number AND NN
		*/
		private function cpuSetRand () : void
		{
			V[(_opcode & 0x0F00) >> 8] = (( Math.random() * 256 ) & (_opcode & 0x00FF));
			
			log("set V" + ((_opcode & 0x0F00) >> 8).toString(16) + " random & " + ((_opcode & 0x00FF)).toString(16) + " = " + V[(_opcode & 0x0F00) >> 8]);
		}
		
		/**
		*	0xDXYN
		*	Draws a sprite at (X,Y) that is N pixels high
		*/
		private function cpuDrawSprite () : void
		{
			var x : uint = V[(_opcode & 0x0F00) >> 8];
			var y : uint = V[(_opcode & 0x00F0) >> 4];
			var h : uint = _opcode & 0x000F;	// Height of sprite
			var p : uint;	// The current pixel/bit
			var l : uint;	// Position in the VRAM
			var xl:uint,yl:uint;
			
			//_memory.forEach( traceVector );
			
			//trace("begin draw ---------------");
			
			V[0xF] = 0;
			if(h == 0)	// 16x16 sprite
			{
				for(yl = 0; yl < 32; yl += 2)
				{
					p = (_memory[ I + yl ] << 8) | _memory[ I + yl + 1 ];
					//trace("p",p.toString(2));
					
					for(xl = 0; xl < 16; xl++)
					{
						//trace( p & (0x8000 >> xl) );
						if( (p & (0x8000 >> xl)) != 0 )	// If this pixel is set to 1
						{
							l = ((x + xl) % _screen.width) + (((y + (yl/2)) % _screen.height) * _screen.width);
							if( _vram[ l ] == 1 )	// Collision detection
								V[0xF] = 1;
							_vram[ l ] = !_vram[ l ];	// Flip the pixel
						}
					}
				}
			}
			else	// 8xh sprite
			{
				for(yl = 0; yl < h; yl++)
				{
					p = _memory[ I + yl ];
					
					for(xl = 0; xl < 8; xl++)
					{
						if( (p & (0x80 >> xl)) != 0 )	// If this pixel is set to 1
						{
							l = ((x + xl) % _screen.width) + (((y + yl) % _screen.height) * _screen.width);
							if( _vram[ l ] == 1 )	// Collision detection
								V[0xF] = 1;
							_vram[ l ] = !_vram[ l ];	// Flip the pixel
						}
					}
				}
			}
			
			_drawFlag = true;
			
			log("draw " + ((h == 0) ? 16 : 8) + "x" + ((h == 0) ? 16 : h) + " at " + x + "," + y);
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
					if( _keymap.key( V[(_opcode & 0x0F00) >> 8] ) )	// If the key stored in VX is pressed
						_pc += 2;
					
					log("skip next if key in V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = " + _keymap.key( V[(_opcode & 0x0F00) >> 8] ));
					break;
				case 0xA1:
					if( !_keymap.key( V[(_opcode & 0x0F00) >> 8] ) )	// If the key stored in VX isn't pressed
						_pc += 2;
					
					log("skip next if no key in V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = " + !_keymap.key( V[(_opcode & 0x0F00) >> 8] ));
					break;
				default:
					nop();
					break;
			}
		}
		
		/**
		*	0xF000
		*	Miscellaneous but important CPU operations
		*/
		private function cpuMisc () : void
		{
			var i:uint;
			switch( _opcode & 0x00FF )
			{
				case 0x07:	// Sets VX to the value of the delay timer
					V[(_opcode & 0x0F00) >> 8] = _delayTimer;
					
					log("set delay to V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = " + _delayTimer.toString(16));
					break;
				case 0x0A: // A key press is awaited, and then stored in VX
					var pressed : Boolean;
					for(i = 0; i < 16; i++)
					{
						if( _keymap.key(i) )
						{
							V[(_opcode & 0x0F00) >> 8] = i;
							pressed = true;
						}
					}
					if(!pressed)	// If no input was detected move pointer back and try command again
						_pc -= 2;
					
					log("waiting for key store in V" + ((_opcode & 0x0F00) >> 8).toString(16));
					break;
				case 0x15:	// Sets the delay timer to VX
					_delayTimer = V[(_opcode & 0x0F00) >> 8];
					
					log("set delay to V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = " + _delayTimer.toString(16));
					break;
				case 0x18:	// Sets the sound timer to VX
					_soundTimer = V[(_opcode & 0x0F00) >> 8];
					
					log("set sound to V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = " + _soundTimer.toString(16));
					break;
				case 0x1E:	// Add VX to I
					if(I + V[(_opcode & 0x0F00) >> 8] > 0xFFF)	// VF is set to 1 when range overflow (I+VX>0xFFF), and 0 when there isn't.
					{
						V[0xF] = 1;
					}
					else
					{
						V[0xF] = 0;
					}
					I += V[(_opcode & 0x0F00) >> 8];
					I %= 0xFFF;
					
					log("add V" + ((_opcode & 0x0F00) >> 8) + " to I = " + I.toString(16) + " : VF=" + V[0xF]);
					break;
				case 0x29:	// Sets I to the location of the sprite for the character in VX
					I = V[(_opcode & 0x0F00) >> 8] * 0x5;
					I %= 0xFFF;
					
					log("set I sprite loc in V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = " + I.toString(16));
					break;
				case 0x30:	// SCHIP : Sets I to the location of the sprite for the character in VX
					I = V[(_opcode & 0x0F00) >> 8] * 10 + 0x50;
					I %= 0xFFF;
					
					log("set I sprite loc in V" + ((_opcode & 0x0F00) >> 8).toString(16) + " = " + I.toString(16));
					break;
				case 0x33:	// Stores the Binary-coded decimal representation of VX at the addresses I, I plus 1, and I plus 2
					_memory[ I ]		= V[(_opcode & 0x0F00) >> 8] / 100;
					_memory[ I + 1 ]	= (V[(_opcode & 0x0F00) >> 8] / 10) % 10;
					_memory[ I + 2 ]	= (V[(_opcode & 0x0F00) >> 8] % 100) % 10;
					
					log("store BCD");
					break;
				case 0x55:	// Copies V0 to VX to memory starting at adress I
					for(i = 0; i <= (_opcode & 0x0F00) >> 8; i++)
					{
						_memory[I + i] = V[i];
					}
					
					log("V0..V" + ((_opcode & 0x0F00) >> 8).toString(16) + " to memory from I=" + I.toString(16));
					// On the original interpreter, when the operation is done, I = I + X + 1.
					/*I += ((_opcode & 0x0F00) >> 8) + 1;
					I %= 0xFFF;*/
					break;
				case 0x65:	// Fills V0 to VX with values from memory starting at address I
					for(i = 0; i <= (_opcode & 0x0F00) >> 8; i++)
					{
						V[i] = _memory[I + i];
					}
					
					log("memory from I=" + I.toString(16) + " to V0..V" + ((_opcode & 0x0F00) >> 8).toString(16));
					// On the original interpreter, when the operation is done, I = I + X + 1.
					/*I += ((_opcode & 0x0F00) >> 8) + 1;
					I %= 0xFFF;*/
					break;
				case 0x75:	// Set HP48 flags from V0..VX (V<8)
					for(i = 0; i <= (_opcode & 0x0F00) >> 8; i++)
					{
						if(i == 8)
							break;
						_hpFlags[i] = V[i];
					}
					
					log("set HP48 flags from V0..V" + (i).toString(16));
					break;
				case 0x85:	// Set V0..VX (V<8) from HP48 flags
					for(i = 0; i <= (_opcode & 0x0F00) >> 8; i++)
					{
						if(i == 8)
							break;
						V[i] = _hpFlags[i];
					}
					
					log("set V0..V" + (i).toString(16) + "from HP48 flags");
					break;
				default:
					nop();
					break;
			}
		}
		
	}	// End Class
}	// End Package