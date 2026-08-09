# PID Controller -- Ruby implementation
# First-order plant: y[k+1] = y[k] + (dt/tau) * (u[k] - y[k])
# PID: u = Kp*e + Ki*I + Kd*D
# Outputs y at each timestep for verification.

def simulate_pid(kp: 2.0, ki: 5.0, kd: 0.1, tau: 1.0, dt: 0.01,
                 setpoint: 1.0, sim_time: 10.0)
  steps = (sim_time / dt).to_i
  y = 0.0
  integral = 0.0
  e_prev = 0.0
  results = []

  steps.times do |k|
    e = setpoint - y
    integral += e * dt
    derivative = (e - e_prev) / dt
    u = kp * e + ki * integral + kd * derivative

    # First-order plant
    y = y + (dt / tau) * (u - y)

    results << { t: k * dt, y: y, u: u }
    e_prev = e
  end

  results
end

if __FILE__ == $0
  results = simulate_pid
  results.each do |r|
    printf("%.4f %.8f %.8f\n", r[:t], r[:y], r[:u])
  end
end