/* PID Controller -- C implementation
 * First-order plant: y[k+1] = y[k] + (dt/tau) * (u[k] - y[k])
 * PID: u = Kp*e + Ki*I + Kd*D
 * Outputs y at each timestep for verification.
 */
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    /* Parameters (can be overridden via command line) */
    double Kp = 2.0, Ki = 5.0, Kd = 0.1;
    double tau = 1.0, dt = 0.01, setpoint = 1.0;
    double sim_time = 10.0;

    if (argc >= 7) {
        Kp = atof(argv[1]);
        Ki = atof(argv[2]);
        Kd = atof(argv[3]);
        tau = atof(argv[4]);
        dt = atof(argv[5]);
        setpoint = atof(argv[6]);
    }
    if (argc >= 8) {
        sim_time = atof(argv[7]);
    }

    int steps = (int)(sim_time / dt);
    double y = 0.0;      /* process variable */
    double integral = 0.0;
    double e_prev = 0.0;

    for (int k = 0; k < steps; k++) {
        double e = setpoint - y;
        integral += e * dt;
        double derivative = (e - e_prev) / dt;
        double u = Kp * e + Ki * integral + Kd * derivative;

        /* First-order plant */
        y = y + (dt / tau) * (u - y);

        /* Output: time, y, u */
        printf("%.4f %.8f %.8f\n", k * dt, y, u);

        e_prev = e;
    }

    return 0;
}