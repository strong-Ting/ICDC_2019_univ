
`timescale 1ns/10ps

module  CONV(clk,reset,busy,ready,iaddr,idata,cwr,caddr_wr,cdata_wr,crd,caddr_rd,cdata_rd,csel);
input clk;
input reset;
input ready;
output busy;
output [11:0] iaddr;
input [19:0] idata;
output crd;
input [19:0] cdata_rd;
output [11:0] caddr_rd;
output cwr;
output [19:0] cdata_wr;
output [11:0] caddr_wr;
output [2:0] csel;
	
//reg or wire 
reg busy;
reg [11:0] iaddr;
reg crd;
reg [11:0] caddr_rd;
reg cwr;
reg signed [19:0] cdata_wr;
reg [11:0] caddr_wr;
reg [2:0] csel;

reg [2:0] current_State;
reg [2:0] next_State;

//parameter
parameter IDLE = 3'd0;
parameter READ = 3'd1;
parameter CONV = 3'd2;
parameter WRITE_L0 = 3'd3;
parameter READ_L0 = 3'd4;
parameter MAX_POOLING = 3'd5;
parameter WRITE_L1 = 3'd6;
parameter FINISH = 3'd7;

//kernel
parameter K0 = 20'h0A89E ;
parameter K1 = 20'h092D5 ;
parameter K2 = 20'h06D43 ;
parameter K3 = 20'h01004 ;
parameter K4 = 20'hF8F71 ;
parameter K5 = 20'hF6E54 ;
parameter K6 = 20'hFA6D7 ;
parameter K7 = 20'hFC834 ;
parameter K8 = 20'hFAC19 ;

//state switch
always@(posedge clk or posedge reset)
begin
    if(reset) current_State = IDLE;
    else current_State = next_State;
end

//next state logic
always@(*)
begin
    case (current_State)
        IDLE:
            begin
                if(ready == 1'd1) next_State = READ;
                else next_State = IDLE;
            end
        READ:
            begin
                if()
            end
        CONV:
            begin
                
            end
        WRITE_L0:
        READ_L0:
        MAX_POOLING:
        WRITE_L1:
        FINISH: 
        default: 
    endcase    
end




endmodule




