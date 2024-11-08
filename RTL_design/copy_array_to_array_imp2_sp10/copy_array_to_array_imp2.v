//////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2010 Gandhi Puvvada, EE-Systems, VSoE, USC
//
// This design exercise, its solution, and its test-bench are confidential items.
// They are University of Southern California's (USC's) property. All rights are reserved.
// Students in our courses have right only to complete the exercise and submit it as part of their course work.
// They do not have any right on our exercise/solution or even on their completed solution as the solution contains our exercise.
// Students would be violating copyright laws besides the University's Academic Integrity rules if they post or convey to anyone
// either our exercise or our solution or their solution (their completed exercise). 
// 
// THIS COPYRIGHT NOTICE MUST BE RETAINED AS PART OF THIS FILE (AND ITS SOLUTION AND/OR ANY OTHER DERIVED FILE) AT ALL TIMES.
//
//////////////////////////////////////////////////////////////////////////////
//
// A student would be violating the University's Academic Integrity rules if he/she gets help in writing or debugging the code 
// from anyone other than the help from his/her teaching team members in completing the exercise(s). 
// However he/she can discuss with fellow students the method of solving the exercise. 
// But writing the code or debugging the code should not be with the help of others. 
// One should never share the code or even look at the code of others (code from classmates or seniors 
// or any code or solution posted online or on GitHub).
// 
// THIS NOTICE OF ACADEMIC INTEGRITY MUST BE RETAINED AS PART OF THIS FILE (AND ITS SOLUTION AND/OR ANY OTHER DERIVED FILE) AT ALL TIMES.
//
//////////////////////////////////////////////////////////////////////////////



// ---------------------------------------------------------------------------------
//  Module: copy_array_to_array_imp2
//  File name:  copy_array_to_array_imp2.v
// 	By: Ananth Rampura Sheshagiri Rao, Gandhi Puvvada
//  Date: 10/26/2009, 1/31/2010, 3/10/2010

//  Description: Given a sorted array M[I] of ten unsigned numbers,
//  create an array N[J] of ten signed numbers. 
//				The 2-D arrays of memory
//               are declared in the testbench and the index and corresponding 
//               element are passed between the testbench and UUT.
// ---------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module copy_array_to_array_imp2 (Reset, Clk, Start, Ack, Ms_of_I, Ns_of_J_Write, I, J);

// Special note:  // ** TODO **  Actually there is nothing to do here, 
		// except you read this paragraph carefully.
// The testbench or the TOP design has the memory arrays.
// This sub-design sends I to the top and received M[I], 
// inspects if M[I][3] is 0 or 1 to see if the number 
// belongs to chunk#1 or chunk#2.
// To deposit it into Ns_of_J (standing for N[J]), this sub-design sends
// to the testbench or the TOP the two items, J and Ns_of_J_Write.  Ns_of_J gets   
// written at the end of the clock synchronously in the testbench or the TOP design.
// The pointers I and J are maintained and updated here in the sub-design.

//inputs and outputs declaration
input Reset, Clk;
input Start, Ack;
input [3:0] Ms_of_I; // Ms_of_I stands for M[I]; similarly Ns_of_J stands for N[J]
output Ns_of_J_Write;
output [3:0] I, J; //I and J are counters for memory indexing

// reg and wire declaration
wire Ns_of_J_Write;
reg [3:0] I,J;  
reg [2:0] state;

// State machine states
localparam
 INI   = 3'b000,
 LS2C  = 3'b001,
 CBC   = 3'b010,
 DONE  = 3'b100,
 UNKN  = 3'bxxx;
 
localparam 
 Imax  = 4'b1001, Jmax = 4'b1001; // Both Imax and Jmax are 9. 0 to 9 make ten elements.
 
// OFL  // ** TODO **  Actually there is nothing to do here, 
		// except you read this paragraph carefully.
// Note: Here we have deviated from our RTL coding style and created a combinational OFL
assign Ns_of_J_Write = ( ((state == LS2C) && (Ms_of_I[3]) ) || (state == CBC) );
// Note that we should not, by mistake, be generating the above signal, Ns_of_J_Write, 
// in the clocked procedural block below. If we do so, we will have a clock delay 
// in activating (and inactivating) Ns_of_J_Write. Solely to make this point, we have 
// coded the design with memories in the top/test bench.  

//start of state machine
always @(posedge Clk, posedge Reset) //asynchronous active_high Reset
 begin  
	   if (Reset) 
	       begin
	           I <= 4'bXXXX;
	           J <= 4'bXXXX;
			   state <= INI;
	       end
       else // under positive edge of the clock
         begin
            case (state) // state and data transfers
                 INI:
					begin
					// state transitions
                        if(Start) 
							state <= LS2C;
					// RTL in DPU
					   	I <= 4'b0000;
						J <= 4'b0000;
					end
                       
                 LS2C:       // ** TODO **  complete RTL Operations and State Transitions            
                    begin  // Please see the "assign Ns_of_J_Write = ...." line in the OFL
					// state transitions
						if ((Ms_of_I[3]) || (I == Imax)) 
							state <= CBC;
					
					//RTL
						I <= I+1;
						if (Ms_of_I[3]) 
							J <= J+1;
						if (I == Imax) 
							I <= 4'b0000;
  
                    end
					
                 CBC:       // ** TODO **  complete RTL Operations and State Transitions
					begin // Please see the "assign Ns_of_J_Write = ...." line in the OFL
					// state transitions
						if (J == Jmax)
							state <= DONE;
 
					//RTL
						I <= I+1;
						J <= J+1;
						if (I == Imax) 
							I <= 4'b0000;
					
                    end
                                               
                 DONE:
                    begin
                        if(Ack)
							state <= INI;
						// else state <= DONE;
                    end
				default: 
                    begin
                         state <= UNKN;    
                    end
            endcase
         end   
 end // end of always procedural block 
               
 endmodule