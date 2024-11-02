`timescale 1ns / 1ps

module vga_bitchange(
	input clk,
	input bright,
	input start,
	input BtnL,
	input BtnR,
	input [9:0] hCount, vCount,
	output reg [11:0] rgb,
	output reg [7:0] score,
	output reg [3:0] lives
   );
	
	parameter BLACK = 12'b0000_0000_0000;
	parameter WHITE = 12'b1111_1111_1111;
	parameter RED   = 12'b1111_0000_0000;
	parameter GREEN = 12'b0010_0101_0001;
	parameter BROWN = 12'b1000_0100_0000;
	//parameter BLUE = 12'b0000_0000_1111;

	wire basket;
	wire apple;
	reg reset;
	wire catched;
	reg[9:0] appleY;
	reg[9:0] appleX;
	reg[9:0] basketX;
	reg[49:0] appleSpeed; 
	reg[49:0] counter; 
	reg[49:0] speedthreshhold;
	wire [11:0] color_data_basket, color_data_apple, color_data_woods;

	
	initial begin
		appleX = 10'd300;
		basketX = 10'd300;
		appleY = 10'd0;
		score = 7'd0;
		lives = 4'd0;
		reset = 1'b0;
		speedthreshhold = 50'd700000;
	end
	
	
	always@ (*)
    	if (~bright)
			rgb = BLACK; // force black if not bright
		else if (apple == 1)
			rgb = color_data_apple; //apple
		else if (basket == 1)
			rgb = color_data_basket; // basket
		else 
			rgb = GREEN; // trees
		
	assign catched = (appleY >= 10'd415) && (appleY <= 10'd455)
					 && (appleX >= basketX - 10'd40) && (appleX <= basketX + 10'd40);

	always@ (posedge clk, posedge start)
		begin
		if (start) 
		begin
			appleX = 10'd300;
			basketX = 10'd300;
			appleY = 10'd0;
			score = 7'd0;
			lives = 4'd5;
			reset = 1'b0;
			speedthreshhold = 50'd700000;
		end
		else 
		begin
			appleSpeed = appleSpeed + 50'd1;

			if (appleSpeed >= speedthreshhold) //500 thousand
			begin
				appleY = appleY + 10'd1;
				appleSpeed = 50'd0;
				if (appleY == 10'd779)
					begin
						lives = lives - 4'd1;
						appleY <= 10'd0;
					end
			end
			
			if (catched) 
			begin
			appleY <= 10'd0;
			end
			
			if (BtnL || BtnR)
			begin
				counter = counter + 50'd1;
			end

			if (counter >= 50'd220000) 
			begin
				if (BtnL) 
				begin
					basketX <= basketX - 10'd1;
					if (basketX < 10'd184)
						basketX <= 10'd184;
				end
				else if (BtnR)
				begin
					basketX <= basketX + 10'd1;
					if (basketX > 10'd740)
						basketX <= 10'd740;
				end
				counter = 50'd0;
			end
			
			if ((reset == 1'b0) && (hCount >= 10'd144) && (hCount <= 10'd784) && catched)
                begin
                score = score + 8'd1;
                reset = 1'b1;
                if (speedthreshhold > 50'd450000)
			         speedthreshhold = speedthreshhold - 50'd30000;
                else if (speedthreshhold > 50'd300000)
                     speedthreshhold = speedthreshhold - 50'd16000;
                else 
                     speedthreshhold = speedthreshhold - 50'd8000;
                end
            
            if (appleY < 10'd20)
                begin
                reset = 1'b0;
                appleX = (appleX + 10'd450) % 540 + 170;
                end

			if (lives == 4'd0) 
			begin
				appleX = 10'd300;
				basketX = 10'd300;
				appleY = 10'd60;
				reset = 1'b0;
				speedthreshhold = 50'd700000;
			end
		
		end
		
		end

    basket_rom basket_rom_unit(.clk(clk), .row(vCount - 10'd450), .col(hCount - (basketX - 10'd32)), .color_data(color_data_basket));
	assign basket = ((hCount >= basketX - 10'd32) && (hCount <= basketX + 10'd32)) && ((vCount >= 10'd450) && (vCount <= 10'd482)) ? 1 : 0;
    
	apple_rom apple_rom_unit(.clk(clk), .row(vCount-appleY), .col(hCount- (appleX-10'd16)), .color_data(color_data_apple));
	assign apple = ((hCount >= appleX - 10'd16) && (hCount <= appleX + 10'd16)) &&
				   ((vCount >= appleY) && (vCount <= appleY + 10'd32)) ? 1 : 0;

endmodule