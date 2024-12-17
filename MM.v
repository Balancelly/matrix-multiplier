`timescale 1ns/10ps
module MM( in_data, col_end, row_end, is_legal, out_data, rst, clk , change_row,valid,busy);
input           clk;
input           rst;
input           col_end;
input           row_end;
input signed     [7:0]     in_data;

output reg signed [19:0]   out_data;
output reg is_legal;
output reg change_row,valid,busy;

parameter load_a=3'd0,load_b=3'd1,hold=3'd2,cal=3'd3,output_s=3'd4,finish=3'd5;

reg [3:0] i_counter,j_counter;
reg [1:0] current_row_counter,a_row,a_col,b_row,b_col,c_row_counter,c_col_counter;
reg [4:0] cal_counter,o_counter;

reg signed[7:0] a [0:15];
reg signed[7:0] b [0:15];
reg signed[19:0] m [0:15];

reg [2:0] cs,ns;
reg [4:0] load_b_counter;

//cs
always@(posedge clk or posedge rst)begin
	if(rst)begin
		cs <= load_a;
	end
	else begin
		cs <= ns;
	end
end

//fsm
always@(*)begin
	case(cs)
		load_a://0
		begin 
			if(col_end && row_end)begin//when two matrix are all input
				ns = load_b;
			end
			else begin
				ns =load_a;
			end
		end
		load_b://1
		begin 
			if(col_end && row_end)begin//when two matrix are all input
				ns = hold;
			end
			else begin
				ns =load_b;
			end
		end
		hold://2比較
		begin
			if(a_col!=b_row)begin
				ns=finish;
			end
			else begin
				ns=cal;
			end
		end
		cal://3
		begin
			if(cal_counter==5'd16)begin
				ns = output_s;
			end
			else begin
				ns = cal;
			end
		end
		output_s://4
		begin
			if(c_col_counter==b_col && c_row_counter==a_row)begin
				ns=finish;
			end
			else begin
				ns=output_s;
			end
		end
		finish:ns=load_a;//5
		default:ns=finish;
	endcase
end

//==============================================================================================================
//control line
//is_legal
always@(*)begin
	if(cs==load_a || cs==load_b||cs==output_s) is_legal=1'b1; 
	else is_legal=1'b0;
end

//busy/need change
always@(*)begin
	if(cs==load_a||cs==load_b||cs==finish)begin //只要有拉就好
		busy=1'b0;
	end
	else begin
		busy=1'b1;
	end
end

//valid
always@(posedge clk or posedge rst)begin
	if(rst)begin
		valid<=1'b0;
	end
	else begin
		if(cs==output_s||(cs==hold && a_col!=b_row)) valid<=1'b1;//output完接finish 故finish會拉 且若不相等 直接到finish也會拉
		else valid<=1'b0;
	end
end

always@(posedge clk or posedge rst)begin
	if(rst)begin
		change_row<=1'd0;
	end
	else begin
		if(cs==output_s && c_col_counter==b_col)begin
			change_row<=1'd1;
		end
		else begin
			change_row<=1'd0;
		end
	end
end
//=========================================
//counter
//i_counter/0/4
always@(posedge clk or posedge rst)begin
	if(rst)begin
		i_counter<=4'd0;
	end
	else begin
		if(cs==load_a &&(!col_end))begin //cs==input_s and not change row /row_end_coun=0 cal i
			i_counter<=i_counter+4'd1;
		end
		else if(cs==load_a && col_end==1'd1 && row_end!=1'd1 && current_row_counter==2'd0)begin//current row==0 and next clock change row
			i_counter<=4'd4;
		end
		else if(cs==load_a && col_end==1'd1 && row_end!=1'd1 && current_row_counter==2'd1)begin//current row==1 and next clock change row
			i_counter<=4'd8;
		end
		else if(cs==load_a && col_end==1'd1 && row_end!=1'd1 && current_row_counter==2'd2)begin//current row==2 and next clock change row
			i_counter<=4'd12;
		end
		else if(cs==finish)begin
			i_counter<=4'd0;		
		end
		else begin
			i_counter<=i_counter;
		end
	end
end

//j_counter
always@(posedge clk or posedge rst)begin
	if(rst)begin
		j_counter<=4'd0;
	end
	else begin
		if(cs==load_b && (!col_end))begin //cs==input_s and not change row
			j_counter<=j_counter+4'd1;
		end
		else if(cs==load_b && col_end==1'b1 && row_end!=1'b1 && current_row_counter==2'd0)begin//current row==0 and next clock change row
			j_counter<=4'd4;
		end
		else if(cs==load_b && col_end==1'b1 && row_end!=1'b1 && current_row_counter==2'd1)begin//current row==1 and next clock change row
			j_counter<=4'd8;
		end
		else if(cs==load_b && col_end==1'b1 && row_end!=1'b1 && current_row_counter==2'd2)begin//current row==2 and next clock change row
			j_counter<=4'd12;
		end
		else if(cs==finish)begin//current row==3 and next clock finish one matrix or current row_end==1 finish
			j_counter<=4'd0;
		end
		else begin
			j_counter<=j_counter;
		end
	end
end

//current_row_counter /indicate which row current 
always@(posedge clk or posedge rst)begin
	if(rst)begin
		current_row_counter<=2'd0;
	end
	else begin
		if(cs==load_a && col_end==1'd1 && row_end!=1'd1)begin//when col_end=1,row_counter+1
			current_row_counter<=current_row_counter+2'd1;
		end
		else if(cs==load_b && col_end==1'd1 && row_end!=1'd1)begin//finish one matrix /one state have two matrix
			current_row_counter<=current_row_counter+2'd1;
		end
		else if(col_end==1'd1 && row_end==1'd1)begin
			current_row_counter<=2'd0;
		end
		else begin
			current_row_counter<=current_row_counter;
		end
	end
end

//a_row 0 1=2row
always@(posedge clk or posedge rst)begin
	if(rst)begin
		a_row<=2'd0;
	end
	else begin
		if(cs==load_a && col_end && !row_end)begin
			a_row<=a_row+2'd1;
		end
		else if(cs==load_a && col_end && row_end)begin//when output row==input a row
			a_row<=a_row;
		end
		else if(cs==finish)begin
			a_row<=2'd0;
		end
	end
end

//a_col 0 =1col
always@(posedge clk or posedge rst)begin
	if(rst)begin
		a_col<=2'd0;
	end
	else begin
		if(cs==load_a && !col_end&&a_row==2'd0)begin
			a_col<=a_col+2'd1;
		end
		else if(cs==finish)begin//when output row==input a row
			a_col<=2'd0;
		end
		else begin
			a_col<=a_col;
		end
	end
end

//b_row 0=1row
always@(posedge clk or posedge rst)begin
	if(rst)begin
		b_row<=2'd0;
	end
	else begin
		if(cs==load_b && col_end && !row_end)begin
			b_row<=b_row+2'd1;
		end
		else if(cs==load_a && col_end && row_end)begin
			b_row<=b_row;
		end
		else if(cs==finish)begin
			b_row<=2'd0;
		end
	end
end

//b_col 2=3row
always@(posedge clk or posedge rst)begin
	if(rst)begin
		b_col<=2'd0;
	end
	else begin
		if(cs==load_b && !col_end&&b_row==2'd0)begin
			b_col<=b_col+2'd1;
		end
		else if(cs==finish)begin
			b_col<=2'd0;
		end
		else begin
			b_col<=b_col;
		end
	end
end

//c_row_counter
always@(posedge clk or posedge rst)begin
	if(rst)begin
		c_row_counter<=2'd0;
	end
	else begin
		if(cs==output_s && c_col_counter==b_col && c_row_counter<a_row)begin //when c_col=b_col to next row
			c_row_counter<=c_row_counter+2'd1;
		end
		else if(cs==output_s && c_col_counter==b_col && c_row_counter==a_row)begin //when c_row=a_row && c_col=b_col  to 0
			c_row_counter<=2'd0;
		end
		else begin
			c_row_counter<=c_row_counter;
		end
	end
end
	
//c_col_counter
always@(posedge clk or posedge rst)begin
	if(rst)begin
		c_col_counter<=2'd0;
	end
	else begin
		if(cs==output_s && c_col_counter<b_col)begin //0<2(bcol)
			c_col_counter<=c_col_counter+2'd1;
		end
		else if(cs==output_s && c_col_counter==b_col)begin//0=2
			c_col_counter<=2'd0;
		end
		else begin
			c_col_counter<=c_col_counter;
		end
	end
end

//cal_counter
always@(posedge clk or posedge rst)begin
	if(rst)begin
		cal_counter<=5'd0;
	end
	else begin
		if(cs==cal && cal_counter<5'd16)begin
			cal_counter<=cal_counter+5'd1;
		end
		else if(cs==cal && cal_counter==5'd16)begin
			cal_counter<=5'd0;
		end
		else begin
			cal_counter<=cal_counter;
		end
	end
end

//load_b_counter
always@(posedge clk or posedge rst)begin
	if(rst)begin
		load_b_counter<=5'd0;
	end
	else begin
		if(cs==load_b)begin
			load_b_counter<=load_b_counter+5'd1;
		end
		else begin
			load_b_counter<=5'd0;
		end
	end
end
//======================================================
//a matrix data
always@(posedge clk or posedge rst)begin
	if(rst)begin
		a[0]<=8'd0;
		a[1]<=8'd0;
		a[2]<=8'd0;
		a[3]<=8'd0;
		a[4]<=8'd0;
		a[5]<=8'd0;
		a[6]<=8'd0;
		a[7]<=8'd0;
		a[8]<=8'd0;
		a[9]<=8'd0;
		a[10]<=8'd0;
		a[11]<=8'd0;
		a[12]<=8'd0;
		a[13]<=8'd0;
		a[14]<=8'd0;
		a[15]<=8'd0;
	end
	else begin
		if(cs==load_a)begin
			a[i_counter]<= in_data;
		end
		else if(cs==finish)begin
			a[0]<=8'd0;
			a[1]<=8'd0;
			a[2]<=8'd0;
			a[3]<=8'd0;
			a[4]<=8'd0;
			a[5]<=8'd0;
			a[6]<=8'd0;
			a[7]<=8'd0;
			a[8]<=8'd0;
			a[9]<=8'd0;
			a[10]<=8'd0;
			a[11]<=8'd0;
			a[12]<=8'd0;
			a[13]<=8'd0;
			a[14]<=8'd0;
			a[15]<=8'd0;
		end
		else begin
			a[i_counter]<=a[i_counter];
		end
	end
end
		
//b maxtrix
always@(posedge clk or posedge rst)begin
	if(rst)begin
		b[0]<=8'd0;
		b[1]<=8'd0;
		b[2]<=8'd0;
		b[3]<=8'd0;
		b[4]<=8'd0;
		b[5]<=8'd0;
		b[6]<=8'd0;
		b[7]<=8'd0;
		b[8]<=8'd0;
		b[9]<=8'd0;
		b[10]<=8'd0;
		b[11]<=8'd0;
		b[12]<=8'd0;
		b[13]<=8'd0;
		b[14]<=8'd0;
		b[15]<=8'd0;
	end
	else begin
		if(cs==load_b)begin
			b[j_counter]<= in_data;
		end
		else if(cs==finish)begin
			b[0]<=8'd0;
			b[1]<=8'd0;
			b[2]<=8'd0;
			b[3]<=8'd0;
			b[4]<=8'd0;
			b[5]<=8'd0;
			b[6]<=8'd0;
			b[7]<=8'd0;
			b[8]<=8'd0;
			b[9]<=8'd0;
			b[10]<=8'd0;
			b[11]<=8'd0;
			b[12]<=8'd0;
			b[13]<=8'd0;
			b[14]<=8'd0;
			b[15]<=8'd0;
		
		end
		else begin
			b[j_counter]<=b[j_counter];
		end
	end
end

//cal
always@(posedge clk or posedge rst)begin
	if(rst)begin
		m[0]<=8'd0;
		m[1]<=8'd0;
		m[2]<=8'd0;
		m[3]<=8'd0;
		m[4]<=8'd0;
		m[5]<=8'd0;
		m[6]<=8'd0;
		m[7]<=8'd0;
		m[8]<=8'd0;
		m[9]<=8'd0;
		m[10]<=8'd0;
		m[11]<=8'd0;
		m[12]<=8'd0;
		m[13]<=8'd0;
		m[14]<=8'd0;
		m[15]<=8'd0;

	end
	else begin
		if(cs==cal && cal_counter==5'd0)       m[0]<= a[0]*b[0]+a[1]*b[4]+a[2]*b[8]+a[3]*b[12];
		else if(cs==cal && cal_counter==5'd1)  m[1]<= a[0]*b[1]+a[1]*b[5]+a[2]*b[9]+a[3]*b[13];
		else if(cs==cal && cal_counter==5'd2)  m[2]<= a[0]*b[2]+a[1]*b[6]+a[2]*b[10]+a[3]*b[14];
		else if(cs==cal && cal_counter==5'd3)  m[3]<= a[0]*b[3]+a[1]*b[7]+a[2]*b[11]+a[3]*b[15];
		
		else if(cs==cal && cal_counter==5'd4)  m[4]<= a[4]*b[0]+a[5]*b[4]+a[6]*b[8]+a[7]*b[12];
		else if(cs==cal && cal_counter==5'd5)  m[5]<= a[4]*b[1]+a[5]*b[5]+a[6]*b[9]+a[7]*b[13];
		else if(cs==cal && cal_counter==5'd6)  m[6]<= a[4]*b[2]+a[5]*b[6]+a[6]*b[10]+a[7]*b[14];
		else if(cs==cal && cal_counter==5'd7)  m[7]<= a[4]*b[3]+a[5]*b[7]+a[6]*b[11]+a[7]*b[15];
		
		else if(cs==cal && cal_counter==5'd8)  m[8]<= a[8]*b[0]+a[9]*b[4]+a[10]*b[8]+a[11]*b[12];
		else if(cs==cal && cal_counter==5'd9)  m[9]<= a[8]*b[1]+a[9]*b[5]+a[10]*b[9]+a[11]*b[13];
		else if(cs==cal && cal_counter==5'd10) m[10]<= a[8]*b[2]+a[9]*b[6]+a[10]*b[10]+a[11]*b[14];
		else if(cs==cal && cal_counter==5'd11) m[11]<= a[8]*b[3]+a[9]*b[7]+a[10]*b[11]+a[11]*b[15];
		
		else if(cs==cal && cal_counter==5'd12) m[12]<= a[12]*b[0]+a[13]*b[4]+a[14]*b[8]+a[15]*b[12];
		else if(cs==cal && cal_counter==5'd13) m[13]<= a[12]*b[1]+a[13]*b[5]+a[14]*b[9]+a[15]*b[13];
		else if(cs==cal && cal_counter==5'd14) m[14]<= a[12]*b[2]+a[13]*b[6]+a[14]*b[10]+a[15]*b[14];
		else if(cs==cal && cal_counter==5'd15) m[15]<= a[12]*b[3]+a[13]*b[7]+a[14]*b[11]+a[15]*b[15];
		else if(cs==finish)begin
			m[0]<=8'd0;
			m[1]<=8'd0;
			m[2]<=8'd0;
			m[3]<=8'd0;
			m[4]<=8'd0;
			m[5]<=8'd0;
			m[6]<=8'd0;
			m[7]<=8'd0;
			m[8]<=8'd0;
			m[9]<=8'd0;
			m[10]<=8'd0;
			m[11]<=8'd0;
			m[12]<=8'd0;
			m[13]<=8'd0;
			m[14]<=8'd0;
			m[15]<=8'd0;	
		end
		else m[0]<=m[0];
	end
end

//out_data
always@(posedge clk or posedge rst)begin
	if(rst)begin
		out_data<=20'd0;
	end
	else begin
		if(cs==output_s)begin
			out_data<=m[o_counter];
		end
		else begin
			out_data<=out_data;
		end
	end
end
				
//data output		
always@(posedge clk or posedge rst)begin
	if(rst)begin
		o_counter<=5'd0;
	end
	else begin
		if(cs==output_s && c_col_counter<b_col)begin
			o_counter<=o_counter+5'd1;
		end
		else if(cs==output_s && c_col_counter==b_col && b_col==2'd3&& c_row_counter<a_row)begin//
			o_counter<=o_counter+5'd1;
		end
		else if(cs==output_s && c_col_counter==b_col && b_col==2'd2&& c_row_counter<a_row)begin
			o_counter<=o_counter+5'd2;
		end
		else if(cs==output_s && c_col_counter==b_col && b_col==2'd1&& c_row_counter<a_row)begin
			o_counter<=o_counter+5'd3;
		end
		else if(cs==output_s && c_col_counter==b_col && b_col==2'd0&& c_row_counter<a_row)begin
			o_counter<=o_counter+5'd4;
		end
		else if(cs==output_s && c_col_counter==b_col && c_row_counter==a_row)begin
			o_counter<=5'd0;
		end
		else begin
			o_counter<=o_counter;
		end
	end
end

endmodule
