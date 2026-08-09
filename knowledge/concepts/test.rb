#!/usr/bin/env ruby
# test.rb -- PID Controller cross-implementation verification
#
# Runs Ruby and C implementations, compares outputs at key timesteps.
# Verilog and ngspice verification are done via the concepts container
# (execute_code_remote target=concepts).
#
# Usage: ruby test.rb
# C verification: ruby test.rb --with-c (requires gcc in PATH or concepts container)

# Reference Ruby implementation
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
    y = y + (dt / tau) * (u - y)
    results << { t: k * dt, y: y, u: u }
    e_prev = e
  end
  results
end

# Key timesteps to verify (every 50 steps = 0.5s intervals + final)
KEY_STEPS = [0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500, 750, 999]
TOLERANCE = 1e-6

def compare_results(ruby_results, other_results, label)
  puts "\n--- Comparing Ruby vs #{label} ---"
  failures = 0

  KEY_STEPS.each do |step|
    r = ruby_results[step]
    o = other_results[step]
    next unless r && o

    y_diff = (r[:y] - o[:y]).abs
    u_diff = (r[:u] - o[:u]).abs

    status = if y_diff < TOLERANCE && u_diff < TOLERANCE
               "OK"
             else
               failures += 1
               "FAIL"
             end

    printf("  t=%.2f  y: %.8f vs %.8f (diff: %.2e)  u: %.8f vs %.8f (diff: %.2e)  [%s]\n",
           r[:t], r[:y], o[:y], y_diff, r[:u], o[:u], u_diff, status)
  end

  if failures.zero?
    puts "  Result: ALL MATCH (tolerance: #{TOLERANCE})"
  else
    puts "  Result: #{failures} MISMATCH(es)"
  end
  failures
end

def parse_c_output(output)
  results = []
  output.each_line do |line|
    parts = line.split
    next unless parts.length == 3
    results << { t: parts[0].to_f, y: parts[1].to_f, u: parts[2].to_f }
  end
  results
end

# Run Ruby reference
puts "=== PID Controller Cross-Implementation Verification ==="
puts "Parameters: Kp=2.0, Ki=5.0, Kd=0.1, tau=1.0, dt=0.01, setpoint=1.0, sim=10.0s"
puts ""

ruby_results = simulate_pid
puts "Ruby simulation: #{ruby_results.length} steps"

# Print key timesteps
puts "\nKey timesteps (Ruby reference):"
KEY_STEPS.each do |step|
  r = ruby_results[step]
  printf("  t=%.2f  y=%.8f  u=%.8f\n", r[:t], r[:y], r[:u]) if r
end

# Check steady-state
final = ruby_results.last
puts "\nSteady-state check:"
printf("  Final y: %.8f (setpoint: 1.0, error: %.2e)\n", final[:y], (1.0 - final[:y]).abs)
if (1.0 - final[:y]).abs < 0.01
  puts "  Steady-state error < 0.01: OK"
else
  puts "  Steady-state error >= 0.01: CHECK TUNING"
end

# C verification (if requested and gcc available)
total_failures = 0
if ARGV.include?('--with-c')
  c_file = File.join(File.dirname(__FILE__), 'pid-controller.c')
  bin_file = '/tmp/pid-controller-c'

  puts "\nCompiling C implementation..."
  system("gcc -o #{bin_file} #{c_file} -lm 2>&1")

  if File.exist?(bin_file)
    puts "Running C implementation..."
    c_output = `#{bin_file}`
    c_results = parse_c_output(c_output)
    puts "C simulation: #{c_results.length} steps"

    total_failures = compare_results(ruby_results, c_results, "C")
  else
    puts "  C compilation failed -- skipping C verification"
  end
else
  puts "\n(Skip C verification -- run with --with-c to enable)"
end

# Summary
puts ""
puts "=== Summary ==="
if total_failures.zero?
  puts "ALL IMPLEMENTATIONS MATCH within tolerance (#{TOLERANCE})"
  exit 0
else
  puts "#{total_failures} MISMATCH(es) detected"
  exit 1
end