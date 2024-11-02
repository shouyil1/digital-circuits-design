`timescale 1ns / 1ps

module counter(
	input clk,
	input[7:0] displayNumber,
	input[3:0] lives,
	output reg [3:0] anode,
	output reg [6:0] ssdOut	
    );
	 
	reg [20:0] refresh;
	reg [3:0] LEDNumber;
	wire [1:0] LEDCounter;
	
	
	always @ (posedge clk)
	begin
		refresh <= refresh + 21'd1;
	end
	assign LEDCounter = refresh[20:19];
	
	always @ (*)
	 begin
		case (LEDCounter)
		2'b00: begin
			anode = 4'b0111;
			LEDNumber = lives;
				end
		 2'b01: begin
		 	anode = 4'b1011;
		 	LEDNumber = 4'b1111;
		 		end
		2'b10: begin
			anode = 4'b1101;
			LEDNumber = displayNumber/10;
				end
		2'b11: begin
			anode = 4'b1110;
			LEDNumber = displayNumber%10;
				end		
		endcase
	end
	always @ (*)
    begin
        case (LEDNumber)
        4'b0000: ssdOut = 7'b0000001;     
        4'b0001: ssdOut = 7'b1001111; 
        4'b0010: ssdOut = 7'b0010010; 
        4'b0011: ssdOut = 7'b0000110;  
        4'b0100: ssdOut = 7'b1001100;  
        4'b0101: ssdOut = 7'b0100100; 
        4'b0110: ssdOut = 7'b0100000;  
        4'b0111: ssdOut = 7'b0001111;  
        4'b1000: ssdOut = 7'b0000000;     
        4'b1001: ssdOut = 7'b0000100; 
        4'b1111: ssdOut = 7'b1111111;
        default: ssdOut = 7'b0000001; 
        endcase
    end
endmodule
