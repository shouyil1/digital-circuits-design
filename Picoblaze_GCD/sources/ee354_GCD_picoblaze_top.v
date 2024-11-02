//////////////////////////////////////////////////////////////////////////////////

// File Name:		ee354_GCD_picoblaze_top.v 
// Authors:         VIKRAM, CHETHAN, Gandhi Puvvada 2/27/2017
// Improved and ported to Nexys-4: 3/19/2023
//    By: Sasindu Kangara Mudiyanselage, Pavan Manjunath, Hanwen Zhang
// Description: 
// // Original RTL design authors Authors:	Shideh Shahidi, Bilal Zafar, Gandhi Puvvada
// // Create Date:		02/25/08
//
// Revision: 		2.3
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////


module ee354_GCD_top
		(MemOE, MemWR, RamCS, QuadSpiFlashCS, // Disable the three memory chips

        ClkPort,                           // the 100 MHz incoming clock signal
		
		BtnL, BtnU, BtnD, BtnR,            // the Left, Up, Down, and the Right buttons BtnL, BtnR,
		BtnC,                              // the center button (this is our reset in most of our designs)
		Sw7, Sw6, Sw5, Sw4, Sw3, Sw2, Sw1, Sw0, // 8 switches
		Ld7, Ld6, Ld5, Ld4, Ld3, Ld2, Ld1, Ld0, // 8 LEDs
		An3, An2, An1, An0,			       // 4 anodes
		An7, An6, An5, An4,                // another 4 anodes which are not used
		Ca, Cb, Cc, Cd, Ce, Cf, Cg,        // 7 cathodes
		Dp                                 // Dot Point Cathode on SSDs
	  );

	/*  INPUTS */
	// Clock & Reset I/O
	input		ClkPort;	
	// Project Specific Inputs
	input		BtnL, BtnU, BtnD, BtnR, BtnC;	
	input		Sw7, Sw6, Sw5, Sw4, Sw3, Sw2, Sw1, Sw0;
	
	
	/*  OUTPUTS */
	// Control signals on Memory chips 	(to disable them)
	output 	MemOE, MemWR, RamCS, QuadSpiFlashCS;
	// Project Specific Outputs
	// LEDs
	output 	Ld0, Ld1, Ld2, Ld3, Ld4, Ld5, Ld6, Ld7;
	// SSD Outputs
	output 	Cg, Cf, Ce, Cd, Cc, Cb, Ca, Dp;
	output 	An0, An1, An2, An3;	
	output 	An4, An5, An6, An7;	

	
	/*  LOCAL SIGNALS */
	wire		Reset, ClkPort;
	wire		board_clk, sys_clk;
	wire [1:0] 	ssdscan_clk;
	reg [26:0]	DIV_CLK;
	
	wire Start_Ack_Pulse; // BtnL_Pulse
	wire in_AB_Pulse, CEN_Pulse, BtnR_Pulse, BtnU_Pulse;
	reg q_I, q_Sub, q_Mult, q_Done;
	reg [7:0] A, B, AB_GCD, i_count;
	reg [7:0] Ain;
	reg [7:0] Bin;
	reg A_bar_slash_B;
	reg [3:0]	SSD;
	wire [3:0]	SSD3, SSD2, SSD1, SSD0;
	reg [7:0]  SSD_CATHODES;
	
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
// Disable the three memories so that they do not interfere with the rest of the design.
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
	.clk 			(sys_clk)); 

// Reset by press button (active high) or JTAG Loader enabled Program Memory 

	assign kcpsm6_reset = rdl | ( BtnC) ;	

// Unused signals tied off until required.
// Tying to other signals used to minimise warning messages.
 
  assign kcpsm6_sleep = 0;  // Always '0'

// Development Program Memory 
//   JTAG Loader enabled for rapid code development. 
  
  prom_gcd #(
	.C_FAMILY		   ("7S"),  
	.C_RAM_SIZE_KWORDS	(1),  
	.C_JTAG_LOADER_ENABLE	(1))
	program_rom (
	.rdl 			(rdl),
	.enable 		(bram_enable),
	.address 		(address),
	.instruction 	(instruction),
	.clk 			(sys_clk));  
	
//------------
// CLOCK DIVISION

	// The clock division circuitary works like this:
	//
	// ClkPort ---> [BUFGP2] ---> board_clk
	// board_clk ---> [clock dividing counter] ---> DIV_CLK
	// DIV_CLK ---> [constant assignment] ---> sys_clk;
	
	BUFGP BUFGP1 (board_clk, ClkPort); 	

// As the ClkPort signal travels throughout our design,
// it is necessary to provide global routing to this signal. 
// The BUFGPs buffer these input ports and connect them to the global 
// routing resources in the FPGA.

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
//-------------------	
	// In this design, we run the core design at full 100MHz clock!
	assign	sys_clk = board_clk;
	// assign	sys_clk = DIV_CLK[25];

//------------
// INPUT: SWITCHES & BUTTONS
	// BtnL is used as both Start and Acknowledge. 
	// To make this possible, we need a single clock producing  circuit.

ee354_debouncer #(.N_dc(28)) ee354_debouncer_2 
        (.CLK(sys_clk), .RESET(Reset), .PB(BtnL), .DPB( ), 
		.SCEN(Start_Ack_Pulse), .MCEN( ), .CCEN( ));
			 		 
		 // BtnR is used to generate in_AB_Pulse to record the values of 
		 // the inputs A and B as set on the switches.
		 // BtnU is used as CEN_Pulse to allow single-stepping
	assign {in_AB_Pulse, CEN_Pulse} = {BtnR_Pulse, BtnU_Pulse};

ee354_debouncer #(.N_dc(28)) ee354_debouncer_1 
        (.CLK(sys_clk), .RESET(Reset), .PB(BtnR), .DPB( ), 
		.SCEN(BtnR_Pulse), .MCEN( ), .CCEN( ));

ee354_debouncer #(.N_dc(28)) ee354_debouncer_0
        (.CLK(sys_clk), .RESET(Reset), .PB(BtnU), .DPB( ), // complete this instantiation
		.SCEN(BtnU_Pulse), .MCEN( ), .CCEN( )); // to produce BtnU_Pulse from BtnU

//Registers used for registering the SCEN Pulse of BtnL and BtnU
reg Start_Ack_Pulse_Reg; // BtnL_Pulse_Reg		
reg BtnU_Pulse_Reg;
reg start_ack;
reg step_ack;

/*
The original two code snippets, labeled as (A) and (B) below, were commented out 
and were replaced by (A_New) and (B_New).

Two drawbacks in the original code snippets. 
1. Asynchronous clearing of the registers using an acknowledge signal from Picoblaze is unacceptable for two reasons:
   1.1. Even though in this case the acknowledge signal (start_ack or step_ack) is glitch-free in this design 
        (as it is a registered signal by itself). in general such control signals may be produced combinationally 
        and potentially have glitches. So, in a pure synchronous design, asynchronous clearing (or asynchronous 
        presetting) is limited to power-on reset actions.
   1.2. Even if you guarantee glitch-free control signals (start_ack or step_ack) like in this case, 
        these old designs are still unacceptable as they create a DFT violation. 
        DFT stands for "Design for Testability". It is covered in EE658 at USC.  
        
2. Using the Start_Ack_Pulse (in  A) or the BtnU_Pulse (in B) as the clock is highly discouraged and is again a DFT violation.
   DFT requires us to use one clock (the system clock) for all clock operations. 
   These are SCEN pulses and they are not guaranteed to be glitch-free. 
   However, in this particular design situation, it all works well
   because the glitches cause the flip-flops to set multiple times in a short 10ns clock pulse 
   and they die down much before the acknowledge pulse arrives.

*/

/*Depending on the SCEN which is received we make the Start_Ack_Pulse_Reg = 1 and
	Clear it when the acknowledge is received from Picoblaze start_ack */

// Note: An alternative name for the Start_Ack_Pulse is BtnL_Pulse.
// It is the SCEN pulse generated when BtnL is pressed.
// It is prolonged by registering it as Start_Ack_Pulse_Reg.
// The Start_Ack_Pulse_Reg is set by the Start_Ack_Pulse 
// and is reset by start_ack confirmation from the pickblaze software.



  always @(posedge sys_clk, posedge Reset) 	
    begin							
        if (Reset)
		Start_Ack_Pulse_Reg <= 1'b0; // an asynchronous clearing
        else if (start_ack)  
		Start_Ack_Pulse_Reg <= 1'b0; // a   synchronous clearing
		else if (Start_Ack_Pulse)
		Start_Ack_Pulse_Reg <= 1'b1; // a   synchronous setting
	end




	/*Depending on the SCEN which is received we make the BtnU_Pulse_Reg = 1 and
Clear it when the acknowledge is received from Picoblaze step_ack */

// TODO: Complete the "clocked always block" below for BtnU_Pulse (BtnU is the single step button)
// using the above  "clocked always block"  for the Start_Ack_Pulse (it could have been called BtnL_Pulse)
// First read the corresponding section of the .psm file.



  always @(posedge sys_clk, posedge Reset) 	
    begin							
        if (Reset)
		BtnU_Pulse_Reg <= 1'b0; // an asynchronous clearing
        else if (step_ack)  
		BtnU_Pulse_Reg <= 1'b0; // a   synchronous clearing
		else if (BtnU_Pulse)
		BtnU_Pulse_Reg <= 1'b1; // a   synchronous setting
	end

	
//------------
	always @ (posedge sys_clk, posedge Reset)
	begin
		if(Reset)
		begin
			Ain <= 0;
			Bin <= 0;
			A_bar_slash_B <= 0;
		end
		else
		begin
			// TODO: How to take input A and B from only using 8 switches? 
			// Please refer to your ee354_GCD_top.v in your gcd_verilog lab
			if (in_AB_Pulse)
				begin
					A_bar_slash_B <= ~ A_bar_slash_B;  	// should this line be "before" (as shown) 
														// or "after" the "if" statement?
														// Please discuss with your TA.
														// Recall aspects of the non-blocking assignment, and how delta-T 
														// avoids race condition in real (physical) registers operation
					if ( !A_bar_slash_B )  // complete this line
						Ain <= {Sw7, Sw6, Sw5, Sw4, Sw3, Sw2, Sw1, Sw0};
					else
						Bin <= {Sw7, Sw6, Sw5, Sw4, Sw3, Sw2, Sw1, Sw0}; // complete this line
				end
		end
	end
	


	assign Start = BtnL; assign Ack = BtnR;


always @ (*)
	
begin
	// TODO: How to handle inputs to picoblaze?
	case (port_id[1:0])
		2'b01 : in_port <= Ain;
		2'b10 : in_port <= Bin;
		2'b00 : in_port <= {6'b000000,BtnU_Pulse,Start_Ack_Pulse}; 	
		default : in_port <= 8'bXXXXXXXX ;  
	endcase
end	

always @(posedge sys_clk) 	
begin
	// TODO: What is the right type of strobe? write_strobe, k_write_strobe, read_strobe, etc?
	if (write_strobe == 1'b1) 
	begin
		// TODO: Handle Port IDs and outputs from picoblaze. Read your .psm file
		case(port_id[2:0])
		// TODO:Complete all the case statements
			3'b101: begin 
					start_ack <= out_port[0];
					step_ack  <= out_port[1];
					end
			3'b000: begin
					A <= out_port;
					end
			3'b001: begin
					B <= out_port;
					end
			3'b010: begin
					AB_GCD <= out_port;
					end
			3'b011: begin
					i_count <= out_port;
					end

		endcase
		
	end
	
	// 'k_write_strobe' is used to qualify all writes to general output ports using OUTPUTK.
	// TODO: What is the right type of strobe? write_strobe, k_write_strobe, read_strobe, etc?
	if (k_write_strobe == 1'b1) 
	begin
		// TODO: Port ID? Please see your .psm file 
		// There shall be an agreement between the addresses used in the .psm assembly language program
		//   and addresses used in this top design in the fabric logic
		if (port_id[2:0] == 3'b100) 
		begin
			q_I <= out_port[0];
			q_Sub <= out_port[1];
			q_Mult <= out_port[2];
			q_Done <= out_port[3];
			
		end	
	end
		
end
//------------
// OUTPUT: LEDS
	
	assign {Ld7, Ld6, Ld5, Ld4} = {q_I, q_Sub, q_Mult, q_Done};
	assign {Ld3, Ld2, Ld1, Ld0} = {BtnL, BtnU, BtnR, BtnD}; // Reset is driven by BtnC
	// Here
	// BtnL = Start/Ack
	// BtnU = Single-Step
	// BtnR = in_A_in_B
	// BtnD = not used here
	
//------------
// SSD (Seven Segment Display)
	
	//SSDs show Ain and Bin in initial state, A and B in subtract state, and GCD and i_count in multiply and done states.
	// ****** TODO  in Part 2 ******
	// assign y = s ? i1 : i0;  // an example of a 2-to-1 mux coding
	// assign y = s1 ? (s0 ? i3: i2): (s0 ? i1: i0); // an example of a 4-to-1 mux coding
	assign SSD3 = (q_Mult | q_Done) ? AB_GCD[7:4]  : q_I ? Ain[7:4] : A[7:4];
	assign SSD2 = (q_Mult | q_Done) ? AB_GCD[3:0]  : q_I ? Ain[3:0] : A[3:0];
	assign SSD1 = (q_Mult | q_Done) ? i_count[7:4] : q_I ? Bin[7:4] : B[7:4];
	assign SSD0 = (q_Mult | q_Done) ? i_count[3:0] : q_I ? Bin[3:0] : B[3:0];


	// need a scan clk for the seven segment display 
	// 191Hz (100 MHz / 2^19) works well
	assign ssdscan_clk = DIV_CLK[19:18];
	
	assign An3	= !(~(ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 00
	assign An2	= !(~(ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 01
	assign An1	=  !((ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 10
	assign An0	=  !((ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 11
	// permanently inactivate the additional four anodes						 
	assign An7 = 1'b1;
	assign An6 = 1'b1;
	assign An5 = 1'b1;
	assign An4 = 1'b1;
	
	always @ (ssdscan_clk, SSD0, SSD1, SSD2, SSD3)
	begin : SSD_SCAN_OUT
		case (ssdscan_clk) 
				  2'b00: SSD = SSD3;
				  2'b01: SSD = SSD2;
				  
				  2'b10: SSD = SSD1;
				  2'b11: SSD = SSD0;
		endcase 
	end
	
	// and finally convert SSD_num to ssd
	// We convert the output of our 4-bit 4x1 mux

	assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp} = {SSD_CATHODES};

	// Following is Hex-to-SSD conversion
	always @ (SSD) 
	begin : HEX_TO_SSD
		case (SSD) // in this exercise file the dot points are made not to glow by making Dp = 1
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
	
endmodule

