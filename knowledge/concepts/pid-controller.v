// PID Controller -- Verilog implementation
// First-order plant: y[k+1] = y[k] + (dt/tau) * (u[k] - y[k])
// PID: u = Kp*e + Ki*I + Kd*D
//
// Fixed-point arithmetic (Q8.8 format, 16-bit signed)
// Parameters:
//   Kp=2.0, Ki=5.0, Kd=0.1, tau=1.0, dt=0.01, setpoint=1.0
//   sim_time=10.0 (1000 steps)
//
// Outputs y at each timestep via $display for verification.
// Note: Fixed-point introduces quantization error vs floating-point
// Ruby/C implementations. Comparison tolerance is wider for Verilog.

`timescale 1ns / 1ps

module pid_controller(
    input wire clk,
    input wire rst,
    output reg signed [15:0] y_out
);

    // Q8.8 fixed-point: 1.0 = 256
    // Kp = 2.0 -> 512
    // Ki = 5.0 -> 1280
    // Kd = 0.1 -> 26 (rounded from 25.6)
    // tau = 1.0 -> 256
    // dt = 0.01 -> 3 (rounded from 2.56)
    // setpoint = 1.0 -> 256
    // dt/tau = 0.01 -> 3 (approximate)

    parameter signed [15:0] KP = 16'sd512;
    parameter signed [15:0] KI = 16'sd1280;
    parameter signed [15:0] KD = 16'sd26;
    parameter signed [15:0] TAU = 16'sd256;
    parameter signed [15:0] DT = 16'sd3;
    parameter signed [15:0] SETPOINT = 16'sd256;
    parameter STEPS = 1000;

    reg signed [15:0] y;
    reg signed [31:0] integral;  // Wider to prevent overflow
    reg signed [15:0] e_prev;
    reg [31:0] step_count;

    // Error
    wire signed [15:0] e = SETPOINT - y;

    // PID terms (Q8.8 * Q8.8 = Q16.16, shift right 8 to get Q8.8)
    wire signed [31:0] kp_e = (KP * e) >>> 8;
    wire signed [31:0] ki_i = (KI * integral[15:0]) >>> 8;
    wire signed [31:0] kd_d = (KD * (e - e_prev) / DT) >>> 8;
    wire signed [15:0] u = kp_e[15:0] + ki_i[15:0] + kd_d[15:0];

    // Plant update: y = y + (dt/tau) * (u - y)
    wire signed [31:0] plant_update = (DT * (u - y)) / TAU;
    wire signed [15:0] y_next = y + plant_update[15:0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            y <= 16'sd0;
            integral <= 32'sd0;
            e_prev <= 16'sd0;
            step_count <= 0;
            y_out <= 16'sd0;
        end else if (step_count < STEPS) begin
            // Output current y (Q8.8 -> display as decimal)
            $display("%0d %0d %0d", step_count, y, u);

            // Update state
            integral <= integral + (e * DT);
            e_prev <= e;
            y <= y_next;
            y_out <= y_next;
            step_count <= step_count + 1;
        end
    end

endmodule

module tb_pid;
    reg clk, rst;
    wire signed [15:0] y;

    pid_controller dut(.clk(clk), .rst(rst), .y_out(y));

    initial begin
        clk = 0;
        rst = 1;
        #10 rst = 0;
        #20000 $finish;
    end

    always #5 clk = ~clk;
endmodule