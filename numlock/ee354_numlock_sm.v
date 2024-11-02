`timescale 1ns / 1ps


module ee354_numlock_sm(clk, reset, q_I, q_G1get, q_G1, q_G10get, q_G10, q_G101get, q_G101, q_G1011get, q_G1011, q_Opening, q_Bad, 
						U, Z);

	/*  INPUTS */
	// Clock & Reset
	input		clk, reset;
    input       U, Z;
	
	/*  OUTPUTS */
	// store current state
	output q_I, q_G1get, q_G1, q_G10get, q_G10, q_G101get, q_G101, q_G1011get, q_G1011, q_Opening, q_Bad;
	
    reg [10:0] state;	
    reg [3:0] DIV_CLK;
    wire timeout;
	assign timeout = (DIV_CLK[0]) & (DIV_CLK[1]) & (DIV_CLK[2]) & (DIV_CLK[3]);
	assign {q_I, q_G1get, q_G1, q_G10get, q_G10, q_G101get, q_G101, q_G1011get, q_G1011, q_Opening, q_Bad} = state;
		
	// lets make accessing the state information easier within the state machine code
	// each line aliases the approriate state bits and sets up a 1-hot code
	localparam 	QI_NUM 			=	11'b10000000000,
				QG1GET_NUM		=	11'b01000000000,
				QG1_NUM			=	11'b00100000000,
				QG10GET_NUM		=	11'b00010000000,
				QG10_NUM		=	11'b00001000000,
				QG101GET_NUM	=	11'b00000100000,
				QG101_NUM		=	11'b00000010000,
				QG1011GET_NUM	=	11'b00000001000,
				QG1011_NUM		=	11'b00000000100,
				QOPENING_NUM	=	11'b00000000010,
				QBAD_NUM		=	11'b00000000001,
                UNK             =   11'bXXXXXXXXXXX;
	
	
    always @ (posedge clk, posedge reset)  
	begin
        if (reset)
            DIV_CLK <= 0;
        else 
            if (q_Opening)
                DIV_CLK <= DIV_CLK + 1'b1; 
            else
                DIV_CLK <= 0;
	end	


	// NSL AND SM
	always @ (posedge clk, posedge reset)
	begin
		if(reset)
			state <= QI_NUM;
		else 
		begin
			case(state)
				QI_NUM:
                    if (U && !Z) 
                        state <= QG1GET_NUM;
                    else 
                        state <= QI_NUM;
                
				QG1GET_NUM:
                    if (U) 
                        state <= QG1GET_NUM;
                    else 
                        state <= QG1_NUM;
				
                QG1_NUM:
                    if (U)
                        state <= QBAD_NUM;
                    else if (Z)
                        state <= QG10GET_NUM;
                    else
                        state <= QG1_NUM;
				
                QG10GET_NUM:
                    if (Z) 
                        state <= QG10GET_NUM;
                    else 
                        state <= QG10_NUM;
				
                QG10_NUM:
                    if (Z) 
                        state <= QBAD_NUM;
                    else if (U) 
                        state <= QG101GET_NUM;
                    else 
                        state <= QG10_NUM;
				
                QG101GET_NUM:
                    if (U) 
                        state = QG101GET_NUM;
                    else 
                        state <= QG101_NUM;
				
                QG101_NUM:
                    if (Z) 
                        state <= QBAD_NUM;
                    else if (U) 
                        state <= QG1011GET_NUM;
                    else 
                        state <= QG101_NUM;
				
                QG1011GET_NUM:
                    if (!U)
                        state <= QG1011_NUM;
                    else 
                        state <= QG1011GET_NUM;
				
                QG1011_NUM:
                    state <= QOPENING_NUM;
				
                QOPENING_NUM:
                    if (timeout)
                        state <= QI_NUM;
                    else 
                        state <= QOPENING_NUM;
				
                QBAD_NUM:
                    if (!U && !Z) 
                        state <= QI_NUM;
                    else 
                        state <= QBAD_NUM;
				
                default:	
                    state <= UNK;
			endcase
		end
	end
	
	
	
endmodule
