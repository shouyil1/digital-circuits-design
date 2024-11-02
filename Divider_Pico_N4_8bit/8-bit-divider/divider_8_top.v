/*
File     : divider_8_top.v 
Author   : Gandhi Puvvada
Revision  : 1.1, 2.0 (Nexys-3), 3.0 (Nexys-4)
Date : Feb 15, 2008, 10/14/08, 2/12/2012, 10/3/2020, 3/13/2021
*/


/*
 Make sure to use the divider_8_top.xdc file containing pin info.
																					  
*/
module divider_8_top		(   
		MemOE, MemWR, RamCS, QuadSpiFlashCS, // Disable the three memory chips

        ClkPort,                           // the 100 MHz incoming clock signal
		
		BtnL, BtnU, BtnD, BtnR,            // the Left, Up, Down, and the Right buttons 		BtnL, BtnR,
		BtnC,                              // the center button (this is our reset in most of our designs)
		Sw15, Sw14, Sw13, Sw12, Sw11, Sw10, Sw9, Sw8, Sw7, Sw6, Sw5, Sw4, Sw3, Sw2, Sw1, Sw0, // 16 switches
		Ld7, Ld6, Ld5, Ld4, Ld3, Ld2, Ld1, Ld0, // 8 LEDs
		An3, An2, An1, An0,			       // 4 anodes
		An7, An6, An5, An4,                // another 4 anodes (we need to turn these unused SSDs off)
		Ca, Cb, Cc, Cd, Ce, Cf, Cg,        // 7 cathodes
		Dp                                 // Dot Point Cathode on SSDs
	  );
	 
								
	/*  INPUTS */
	// Clock & Reset I/O
	input		ClkPort;	
	// Project Specific Inputs
	input		BtnL, BtnU, BtnD, BtnR, BtnC;	
	input		Sw15, Sw14, Sw13, Sw12, Sw11, Sw10, Sw9, Sw8, Sw7, Sw6, Sw5, Sw4, Sw3, Sw2, Sw1, Sw0;
//*********TODO*************
// You want to use all 16 switches here in the 8-bit divider top	
	
	/*  OUTPUTS */
	// Control signals on Memory chips 	(to disable them)
	output 	MemOE, MemWR, RamCS, QuadSpiFlashCS;
	// Project Specific Outputs
	// LEDs
	output 	Ld0, Ld1, Ld2, Ld3, Ld4, Ld5, Ld6, Ld7;
	// SSD Outputs
	output 	Cg, Cf, Ce, Cd, Cc, Cb, Ca, Dp;
	output 	An0, An1, An2, An3;	
	output  An4, An5, An6, An7; // extra four unused SSDs need to be turned off
	
	/*  LOCAL SIGNALS */
	wire		Reset, ClkPort;
	wire		board_clk; 
// *********TODO*************
// You want to use all 8 SSDs. So you need to control 8 Anodes!
// You may want to take a look at test_nexys4_verilog.v	
	wire [2:0] 	ssdscan_clk;
// *********TODO*************
// Adjust the bit ranges	
	wire [7:0] 	Xin, Yin;
	reg  [7:0] 	Quotient, Remainder;
	wire 		Start, Ack;
	reg 		Done, Qi, Qc, Qd;

// to produce divided clock
	reg [26:0]	DIV_CLK;
// SSD (Seven Segment Display)
	reg [3:0]	SSD;
// *********TODO*************
// You want to use all 8 SSDs.	
	wire [7:0]	SSD7, SSD6, SSD5, SSD4, SSD3, SSD2, SSD1, SSD0;
	reg [7:0]  	SSD_CATHODES;


// Signals used to connect KCPSM6

	wire [11:0] address;
	wire [17:0]	instruction;
	wire        bram_enable;
	reg  [7:0]  in_port;
	wire [7:0]  out_port;
	wire [7:0]  port_id;
	wire        write_strobe;
	wire        k_write_strobe;
	wire        read_strobe;
	reg         interrupt;   
	wire        interrupt_ack;
	wire        kcpsm6_sleep;  
	wire        kcpsm6_reset;
	wire        rdl;	
	
//------------	
// Disable the two memories so that they do not interfere with the rest of the design.
	assign {MemOE, MemWR, RamCS, QuadSpiFlashCS} = 4'b1111;
	
  /////////////////////////////////////////////////////////////////////////////////////////
  // Instantiate KCPSM6 and connect to program ROM
  /////////////////////////////////////////////////////////////////////////////////////////
  //
  // The generics can be defined as required. In this case the 'hwbuild' value is used to 
  // define a version using the ASCII code for the desired letter and the interrupt vector
  // has been set to 3C0 to provide 64 instructions for an Interrupt Service Routine (ISR)
  // before reaching the end of a 1K memory 
  //


  kcpsm6 #(
	.interrupt_vector	(12'h3FF),
	.scratch_pad_memory_size(64),
	.hwbuild		(8'h41))            // 41 hex is ASCII Character "A"
  processor (
	.address 		(address),
	.instruction 	(instruction),
	.bram_enable 	(bram_enable),
	.port_id 		(port_id),
	.write_strobe 	(write_strobe),
	.k_write_strobe (k_write_strobe),
	.out_port 		(out_port),
	.read_strobe 	(read_strobe),
	.in_port 		(in_port),
	.interrupt 		(interrupt),
	.interrupt_ack 	(interrupt_ack),
	.reset 			(kcpsm6_reset),
	.sleep			(kcpsm6_sleep),
	.clk 			(board_clk)); 

// Reset by press button (active Low) or JTAG Loader enabled Program Memory 

	assign kcpsm6_reset = rdl | ( BtnC) ;	

// Unused signals tied off until required.
// Tying to other signals used to minimize warning messages.
 
//	assign kcpsm6_sleep = write_strobe & k_write_strobe;  // Always '0'
	assign kcpsm6_sleep = 0;
// Development Program Memory 
//   JTAG Loader enabled for rapid code development. 
  
  prom_divider_8 #(
	.C_FAMILY		   ("7S"),  
	.C_RAM_SIZE_KWORDS	(1),  
	.C_JTAG_LOADER_ENABLE	(1))
	program_rom (
	.rdl 			(rdl),
	.enable 		(bram_enable),
	.address 		(address),
	.instruction 	(instruction),
	.clk 			(board_clk));  
//------------
// CLOCK DIVISION

	// The clock division circuitry works like this:
	//
	// ClkPort ---> [BUFGP2] ---> board_clk
	// board_clk ---> [clock dividing counter] ---> DIV_CLK
	// DIV_CLK ---> [constant assignment] ---> sys_clk;
	
	// Instantiation of BUFGP is an old practice. The implementation tools provide an appropriate Global Buffer automatically.
	// BUFGP BUFGP1 (board_clk, ClkPort); 	
	assign board_clk = ClkPort;	

// As the ClkPort signal travels throughout our design,
// it is necessary to provide global routing to this signal. 
// The BUFGPs buffer these input ports and connect them to the global 
// routing resources in the FPGA.

	// BUFGP BUFGP2 (Reset, BtnC); In the case of Spartan 3E (on Nexys-2 board), we were using BUFGP to provide global routing for the reset signal. But Spartan 6 (on Nexys-3) does not allow this.
	assign Reset = BtnC;
//------------
	// Our clock is too fast (100MHz) for SSD scanning
	// create a series of slower "divided" clocks
	// each successive bit is 1/2 frequency
  always @(posedge board_clk, posedge Reset) 	
    begin							
        if (Reset)
		DIV_CLK <= 0;
        else
		DIV_CLK <= DIV_CLK + 1'b1;
    end

// *********TODO*************
// You want to use all 16 switches here in the 8-bit divider top	
	assign Xin = {Sw7, Sw6, Sw5, Sw4, Sw3, Sw2, Sw1, Sw0};
	assign Yin = {Sw15, Sw14, Sw13, Sw12, Sw11, Sw10, Sw9, Sw8};
	assign Start = BtnL; assign Ack = BtnR;

// *********TODO*************
// You want to use individual input ports for Xin and Yin in the 8-bit divider top	
// You do not want to concatenate them into one {Xin,Yin}
// You may need 3 read ports with three port addresses	
always @ (*)
begin
	case (port_id[1:0])
		2'b00 : in_port <= Xin;
		2'b01 : in_port <= Yin;
		2'b10 : in_port <= {6'b000000,Start,Ack}; 	
		default : in_port <= 8'bXXXXXXXX ;  
	endcase
end	

// *********TODO*************
// You want to use individual output ports for Quotient and Remainder in the 8-bit divider top	
// You do not want to concatenate them into one {Quotient,Remainder}
// You may need 3 write ports with three port addresses	

always @(posedge board_clk) 	
begin	
	// 'write_strobe' is used to qualify all writes to general output ports using OUTPUT.
	if (write_strobe == 1'b1) 
	begin
		if(port_id[1:0] == 2'b00)begin
			Quotient <= out_port;
		end	
		else if(port_id[1:0] == 2'b01)begin
			Remainder <= out_port;
		end	
	end
	
	// 'k_write_strobe' is used to qualify all writes to general output ports using OUTPUTK.
	if (k_write_strobe == 1'b1) 
	begin
		// Write to output_port at port address 01
		if (port_id[1:0]  == 2'b10) 
		begin
			Done <= out_port[0];
			Qi <= out_port[1];
			Qc <= out_port[2];
			Qd <= out_port[3];
		end	
	end		
end

//------------
// OUTPUT: LEDS
	
	assign {Ld7, Ld6, Ld5, Ld4} = {Qi, Qc, Qd, Done};
	assign {Ld3, Ld2, Ld1, Ld0} = {Start, BtnU, Ack, BtnD}; 
	
//------------
// *********TODO*************
// You want to use all 8 SSDs.
// You may want to take a look at test_nexys4_verilog.v	

// SSD (Seven Segment Display)
	// reg [3:0]	SSD;
	// wire [3:0]	SSD3, SSD2, SSD1, SSD0;
	
	//SSDs display Xin, Yin, Quotient, and Remainder  
	
	assign SSD7 = Xin[7:4];
	assign SSD6 = Xin[3:0];
	assign SSD5 = Yin[7:4];
	assign SSD4 = Yin[3:0];
	assign SSD3 = Quotient[7:4];
	assign SSD2 = Quotient[3:0];
	assign SSD1 = Remainder[7:4];
	assign SSD0 = Remainder[3:0];


	// need a scan clk for the seven segment display 
	
	// 100 MHz / 2^18 = 381.5 cycles/sec ==> frequency of DIV_CLK[17]
	// 100 MHz / 2^19 = 190.7 cycles/sec ==> frequency of DIV_CLK[18]
	// 100 MHz / 2^20 =  95.4 cycles/sec ==> frequency of DIV_CLK[19]
	
	// 381.5 cycles/sec (2.62 ms per digit) [which means all 4 digits are lit once every 10.5 ms (reciprocal of 95.4 cycles/sec)] works well.
	
	//                  --|  |--|  |--|  |--|  |--|  |--|  |--|  |--|  |   
    //                    |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | 
	//  DIV_CLK[17]       |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|
	//
	//               -----|     |-----|     |-----|     |-----|     |
    //                    |  0  |  1  |  0  |  1  |     |     |     |     
	//  DIV_CLK[18]       |_____|     |_____|     |_____|     |_____|
	//
	//         -----------|           |-----------|           |
    //                    |  0     0  |  1     1  |           |           
	//  DIV_CLK[19]       |___________|           |___________|
	//
// *********TODO*************
// You want to use all 8 SSDs. Hence you need to control 8 Anodes.
// You may want to take a look at test_nexys4_verilog.v	

	assign ssdscan_clk = DIV_CLK[19:17];
	assign An0	= !(~(ssdscan_clk[2]) && ~(ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 000
	assign An1	= !(~(ssdscan_clk[2]) && ~(ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 001
	assign An2	= !(~(ssdscan_clk[2]) &&  (ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 010
	assign An3	= !(~(ssdscan_clk[2]) &&  (ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 011
	assign An4	=  !((ssdscan_clk[2]) && ~(ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 100
	assign An5	=  !((ssdscan_clk[2]) && ~(ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 101
	assign An6	=  !((ssdscan_clk[2]) &&  (ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 110
	assign An7	=  !((ssdscan_clk[2]) &&  (ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 111
	
	
	always @ (ssdscan_clk, SSD0, SSD1, SSD2, SSD3)
	begin : SSD_SCAN_OUT
		case (ssdscan_clk) 
				  3'b000: SSD = SSD0;
				  3'b001: SSD = SSD1;
				  3'b010: SSD = SSD2;
				  3'b011: SSD = SSD3;
				  3'b100: SSD = SSD4;
				  3'b101: SSD = SSD5;
				  3'b110: SSD = SSD6;
				  3'b111: SSD = SSD7;
		endcase 
	end

// *********TODO*************
// You want to change the Dp such that the dot points do NOT glow in your design

	// Following is Hex-to-SSD conversion
	always @ (SSD) 
	begin : HEX_TO_SSD
		case (SSD) // in this solution file the dot points are made to glow by making Dp = 0
		    //                                                                abcdefg,Dp
			4'b0000: SSD_CATHODES = 8'b00000011; // 0
			4'b0001: SSD_CATHODES = 8'b10011111; // 1
			4'b0010: SSD_CATHODES = 8'b00100101; // 2
			4'b0011: SSD_CATHODES = 8'b00001101; // 3
			4'b0100: SSD_CATHODES = 8'b10011001; // 4
			4'b0101: SSD_CATHODES = 8'b01001001; // 5
			4'b0110: SSD_CATHODES = 8'b01000001; // 6
			4'b0111: SSD_CATHODES = 8'b00011111; // 7
			4'b1000: SSD_CATHODES = 8'b00000001; // 8
			4'b1001: SSD_CATHODES = 8'b00001001; // 9
			4'b1010: SSD_CATHODES = 8'b00010001; // A
			4'b1011: SSD_CATHODES = 8'b11000001; // B
			4'b1100: SSD_CATHODES = 8'b01100011; // C
			4'b1101: SSD_CATHODES = 8'b10000101; // D
			4'b1110: SSD_CATHODES = 8'b01100001; // E
			4'b1111: SSD_CATHODES = 8'b01110001; // F    
			default: SSD_CATHODES = 8'bXXXXXXXX; // default is not needed as we covered all cases
		endcase
	end	
	
	// reg [7:0]  SSD_CATHODES;
	assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp} = {SSD_CATHODES};
	

endmodule
