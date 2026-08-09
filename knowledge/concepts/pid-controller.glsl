/* GLSL implementation of PID controller
 * Fragment shader that simulates PID control loop.
 * Each texel represents one simulation step (encoded in texture coords).
 * Output: y value encoded in red channel.
 *
 * This is a proof-of-concept showing PID can run on GPU.
 * Parameters: Kp=2.0, Ki=5.0, Kd=0.1, tau=1.0, dt=0.01, setpoint=1.0
 * sim_time=10.0 (1000 steps)
 *
 * Note: GPU floating-point precision may differ from CPU.
 * Comparison tolerance for GLSL: 1e-4 (float32 vs float64).
 */

#version 330 core

uniform float u_Kp = 2.0;
uniform float u_Ki = 5.0;
uniform float u_Kd = 0.1;
uniform float u_tau = 1.0;
uniform float u_dt = 0.01;
uniform float u_setpoint = 1.0;
uniform int u_steps = 1000;

out vec4 fragColor;

void main() {
    // Single-texel simulation: this shader runs the full PID loop
    // and outputs the final y value.
    // In a real GPU implementation, you'd use transform feedback or
    // compute shaders for parallel simulation.

    float y = 0.0;
    float integral = 0.0;
    float e_prev = 0.0;

    for (int k = 0; k < u_steps; k++) {
        float e = u_setpoint - y;
        integral += e * u_dt;
        float derivative = (e - e_prev) / u_dt;
        float u = u_Kp * e + u_Ki * integral + u_Kd * derivative;

        // First-order plant
        y = y + (u_dt / u_tau) * (u - y);

        e_prev = e;
    }

    // Encode y in red channel (0-1 range, y should be ~1.0)
    fragColor = vec4(y, 0.0, 0.0, 1.0);
}