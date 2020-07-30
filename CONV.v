
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

reg [3:0] counterRead;
reg signed [19:0] maskBuffer [0:8];
reg [5:0] index_X,index_Y;
wire [5:0] index_X_After,index_X_Before,index_Y_After,index_Y_Before;



reg signed [43:0] convTemp; // 2^20 * 2^20 * 2^4 = 2^44  By the way 2^4 = 9 pixel
wire signed [20:0] roundTemp;
//get the 4 bits int and 17 bits float then add 1 rounding the 17bit
assign roundTemp = convTemp[35:15] + 21'd1; 
reg signed [19:0] kernelTemp;
reg signed [19:0] maskTemp;

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
parameter Bias = {8'd0,20'h01310,16'd0} ;

always@(*)
begin
    case(counterRead)
    4'd0: kernelTemp = K0;
    4'd1: kernelTemp = K1;
    4'd2: kernelTemp = K2;
    4'd3: kernelTemp = K3;
    4'd4: kernelTemp = K4;
    4'd5: kernelTemp = K5;
    4'd6: kernelTemp = K6;
    4'd7: kernelTemp = K7;
    4'd8: kernelTemp = K8;
    default: kernelTemp = 20'd0;
    endcase
end

always@(*)
begin
    case(counterRead)
    4'd0: maskTemp = maskBuffer[0];
    4'd1: maskTemp = maskBuffer[1];
    4'd2: maskTemp = maskBuffer[2];
    4'd3: maskTemp = maskBuffer[3];
    4'd4: maskTemp = maskBuffer[4];
    4'd5: maskTemp = maskBuffer[5];
    4'd6: maskTemp = maskBuffer[6];
    4'd7: maskTemp = maskBuffer[7];
    4'd8: maskTemp = maskBuffer[8];
    default: maskTemp = 20'd0;
    
    endcase
end
    

//reg signed [19:0] Bias = 20'h01310;




//index x y
assign index_X_Before = index_X - 6'd1;
assign index_X_After = index_X + 6'd1;
assign index_Y_Before = index_Y - 6'd1;
assign index_Y_After = index_Y + 6'd1;

//x y
always@(posedge clk or posedge reset)
begin
    if(reset) index_X <= 6'd0;
    else if(current_State == WRITE_L0) 
    begin
        if(index_X == 6'd63) index_X <= 6'd0;
        else index_X <= index_X + 6'd1;
    end
    else if(current_State == WRITE_L1)
    begin
        if(index_X == 6'd62) index_X <= 6'd0;
        else index_X <= index_X + 6'd2;
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset) index_Y <= 6'd0;
    else if(current_State == WRITE_L0)
    begin
        if(index_X == 6'd63) index_Y <= index_Y + 6'd1;
       // else if(index_Y == 6'd63 && index_X == 6'd63) index_Y <= 6'd0; //useless
    end
    else if(current_State == WRITE_L1)
    begin
        if(index_X == 6'd62) index_Y <= index_Y + 6'd2;
      //  else if(index_Y == 6'd62 && index_X == 6'd62) index_Y <= 6'd0;
    end
end

//counter
always@(posedge clk or posedge reset)
begin
    if(reset) counterRead <= 4'd0;
    else if(counterRead == 4'd9) counterRead <= 4'd0;
    else if(counterRead == 4'd4 && current_State == READ_L0) counterRead <= 4'd0;
    else if(current_State == READ || current_State == CONV || current_State == READ_L0) counterRead <= counterRead + 4'd1;
end

//busy
always@(posedge clk or posedge reset)
begin
    if(reset) busy <= 1'd0;
    else if(ready == 1'd1) busy <= 1'd1;
    else if(current_State == FINISH )busy <= 1'd0;
end

//cwr crd csel
always@(posedge clk or posedge reset)
begin
    if(reset) cwr <= 1'd0;
    else if(current_State == WRITE_L0) cwr <= 1'd1;
    else if(next_State == WRITE_L1) cwr <= 1'd1;
    else if(current_State != WRITE_L0) cwr <= 1'd0;
end

always@(posedge clk or posedge reset)
begin
    if(reset) crd <= 1'd0;
    else if(current_State == READ_L0) crd <= 1'd1;
end

always@(posedge clk or posedge reset)
begin
    if(reset) csel <=3'd0;
    else if(next_State == WRITE_L1) csel <= 3'd3;
    else if(current_State == WRITE_L0) csel <= 3'd1;
    else if(current_State == READ_L0) csel <= 3'd1;
    
end



//state switch
always@(posedge clk or posedge reset)
begin
    if(reset) current_State <= IDLE;
    else current_State <= next_State;
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
                if(counterRead == 4'd9) next_State = CONV;
                else next_State = READ;
            end
        CONV:
            begin
                if(counterRead == 4'd9) next_State = WRITE_L0; //more speed function?
                else next_State = CONV;
            end
        WRITE_L0:
            begin
                if(index_X == 6'd63 && index_Y == 6'd63) next_State = READ_L0;
                else next_State = READ;
            end
        READ_L0:
            begin
                if(counterRead == 4'd4) next_State = MAX_POOLING;
                else next_State = READ_L0;
            end
        MAX_POOLING:
            begin
                next_State = WRITE_L1;
            end
        WRITE_L1:
            begin
                if(index_X == 6'd62 && index_Y == 6'd62) next_State = FINISH;
                else next_State = READ_L0;
            end
        FINISH: 
            begin
                next_State = FINISH;
            end
        default:
            begin
                next_State = IDLE;
            end 
    endcase    
end

//output logic cdata_wr & caddr_wr
always@(posedge clk or posedge reset)
begin
    if(reset) caddr_wr <= 6'd0;
    else if(current_State == WRITE_L0) caddr_wr <= {index_Y,index_X};
    else if(next_State == WRITE_L1) caddr_wr <= {index_Y[5:1],index_X[5:1]} ;
end

always@(posedge clk or posedge reset)
begin
    if(reset) cdata_wr <= 20'd0;
    else if(current_State == WRITE_L0)
    begin
        if(convTemp[43]) cdata_wr <= 20'd0;
        else cdata_wr <= roundTemp[20:1];
    end
    else if(current_State == READ_L0)
    begin
        if(counterRead == 4'd1) cdata_wr <= cdata_rd;
        else 
        begin
            if(cdata_rd > cdata_wr) cdata_wr <= cdata_rd;
            else cdata_wr <= cdata_wr;
        end
    end
end

// caddr_rd
always@(posedge clk or posedge reset)
begin
    if(reset) caddr_rd <= 6'd0;
    else if(current_State == READ_L0)
    begin
        case(counterRead)
        4'd0: caddr_rd <= {index_Y,index_X};
        4'd1: caddr_rd <= {index_Y,index_X_After};
        4'd2: caddr_rd <= {index_Y_After,index_X};
        4'd3: caddr_rd <= {index_Y_After,index_X_After};
        default: caddr_rd <= 6'd0;
        endcase
    end
end

//conv
always@(posedge clk or posedge reset)
begin
    if(reset) convTemp <= 44'd0;
    else if(current_State == CONV) 
    begin
        /*
        convTemp <= maskBuffer[0]* K0 +maskBuffer[1]*K1 +maskBuffer[2]*K2
                +   maskBuffer[3]* K3 +maskBuffer[4]*K4 +maskBuffer[5]*K5
                +   maskBuffer[6]* K6 +maskBuffer[7]*K7 +maskBuffer[8]*K8 
                +   Bias;*/
        /*
        case(counterRead)
        4'd0: convTemp <= maskBuffer[0]*K0;
        4'd1: convTemp <= convTemp + maskBuffer[1]*kernelTemp;
        4'd2: convTemp <= convTemp + maskBuffer[2]*kernelTemp;
        4'd3: convTemp <= convTemp + maskBuffer[3]*kernelTemp;
        4'd4: convTemp <= convTemp + maskBuffer[4]*kernelTemp;
        4'd5: convTemp <= convTemp + maskBuffer[5]*kernelTemp;
        4'd6: convTemp <= convTemp + maskBuffer[6]*kernelTemp;
        4'd7: convTemp <= convTemp + maskBuffer[7]*kernelTemp;
        4'd8: convTemp <= convTemp + maskBuffer[8]*kernelTemp;
        4'd9: convTemp <= convTemp + Bias;
        endcase*/
        if(counterRead == 4'd9) convTemp <= convTemp + Bias;
        else convTemp <= convTemp + kernelTemp*maskTemp;
    end
    else if(current_State == READ) convTemp <= 44'd0;
end


//iaddr
always@(posedge clk or posedge reset)
begin
    if(reset) iaddr <= 6'd0;
    else if(current_State == READ)
    begin
        case(counterRead)
        4'd0: iaddr <= {index_Y_Before,index_X_Before};
        4'd1: iaddr <= {index_Y_Before,index_X};
        4'd2: iaddr <= {index_Y_Before,index_X_After};
        4'd3: iaddr <= {index_Y,index_X_Before};
        4'd4: iaddr <= {index_Y,index_X};
        4'd5: iaddr <= {index_Y,index_X_After};
        4'd6: iaddr <= {index_Y_After,index_X_Before};
        4'd7: iaddr <= {index_Y_After,index_X};
        4'd8: iaddr <= {index_Y_After,index_X_After};
        default: iaddr <= 6'd0;
        endcase
    end
end

//maskBuffer zero padding
always@(posedge clk or posedge reset)
begin
    if(reset) maskBuffer[0] <= 20'd0;
    else if(counterRead == 4'd1 && current_State == READ)
    begin
        if(index_X !=6'd0 & index_Y != 6'd0) maskBuffer[0] <= idata;
        else maskBuffer[0] <= 0;
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset) maskBuffer[1] <= 20'd0;
    else if(counterRead == 4'd2 && current_State == READ)
    begin
        if(index_Y != 6'd0) maskBuffer[1] <= idata;
        else maskBuffer[1] <= 6'd0;
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset) maskBuffer[2] <= 20'd0;
    else if(counterRead == 4'd3 && current_State == READ)
    begin
        if(index_Y != 6'd0 && index_X != 6'd63) maskBuffer[2] <= idata;
        else maskBuffer[2] <= 6'd0;
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset) maskBuffer[3] <= 20'd0;
    else if(counterRead == 4'd4 && current_State == READ)
    begin
        if(index_X != 6'd0) maskBuffer[3] <= idata;
        else maskBuffer[3] <= 6'd0;
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset) maskBuffer[4] <= 20'd0;
    else if(counterRead == 4'd5 && current_State == READ) maskBuffer[4] <= idata;
end

always@(posedge clk or posedge reset)
begin
    if(reset) maskBuffer[5] <= 20'd0;
    else if(counterRead == 4'd6 && current_State == READ)
    begin
        if(index_X != 6'd63) maskBuffer[5] <= idata;
        else maskBuffer[5] <= 6'd0;
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset) maskBuffer[6] <= 20'd0;
    else if (counterRead == 4'd7 && current_State == READ) 
    begin
        if(index_X != 6'd0 && index_Y != 6'd63) maskBuffer[6] <= idata;
        else maskBuffer[6] <= 6'd0;
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset) maskBuffer[7] <= 20'd0;
    else if(counterRead == 4'd8 && current_State == READ)
    begin
        if(index_Y != 6'd63) maskBuffer[7] <= idata;
        else maskBuffer[7] <= 6'd0;
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset) maskBuffer[8] <= 20'd0;
    else if(counterRead == 4'd9 && current_State == READ)
    begin
        if(index_Y != 6'd63 && index_X != 6'd63) maskBuffer[8] <= idata;
        else maskBuffer[8] <= 6'd0;
    end
end

endmodule




