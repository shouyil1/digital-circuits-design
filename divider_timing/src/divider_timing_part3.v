module divider_timing (Xin, Yin, Start, Ack, Clk, Reset,  SCEN,  // Notice SCEN
                Done, Quotient, Remainder, Qi, Qc, Qd);

input [7:0] Xin, Yin;
input Start, Ack, Clk, Reset;
output Done;
input SCEN;
output [7:0] Quotient, Remainder;
output Qi, Qc, Qd;
// local variable declarations
reg [7:0] x_temp, Quo_temp; 
integer I;

reg [7:0] Quotient;  // Remainder is a wire by default
reg [7:0] x, y;
reg [2:0] state;

localparam
INITIAL = 3'b001,
COMPUTE	= 3'b010,
DONE_S	= 3'b100;

assign {Qd, Qc, Qi} = state;

always @(posedge Clk, posedge Reset) 

  begin  : CU_n_DU
    if (Reset)
       begin
            state       <= INITIAL;
            x           <= 8'bXXXX_XXXX;     
            y           <= 8'bXXXX_XXXX;     
            Quotient    <= 8'bXXXX_XXXX;     // to avoid recirculating mux controlled by Reset
       end
    else
       begin
         (* full_case, parallel_case *)
         case (state)
            INITIAL : 
              begin
                  // state transitions in the control unit
                  if (Start)
                      state <= COMPUTE;
                  // RTL operations in the Data Path 
                      x <= Xin;
                      y <= Yin;
                      Quotient <= 0;
              end
            COMPUTE :
			  if (SCEN)  // Notice SCEN
              begin
                x_temp = x; // gather x into x_temp
                Quo_temp = Quotient; // gather Quotient into Quo_temp;

                // state transitions in the control unit
                if (x < y)
                    state <= DONE_S;
                // RTL operations in the Data Path 
                for (I = 0; I <= 7; I = I+1)
                    begin
                        if (x_temp >= y)
                            begin
                                x_temp = x_temp - y;
                                Quo_temp = Quo_temp + 1;
                            end
                    end
                
                x <= x_temp;
                Quotient <= Quo_temp; 
              end 
            DONE_S  :
              begin  
                  // state transitions in the control unit
                  if (Ack)
                      state <= INITIAL;
                  // In DONE_S state, there are no RTL operations in the Data Path 
              end    
      endcase
    end 
  end
 
assign Remainder = x;
assign Done = (state == DONE_S) ;

endmodule  // divider_timing
