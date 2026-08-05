# Ignacio Randazzo -- CV

Source: LaTeX CV at `~/iar-workspace/cv/` (cv-eng.tex, cv-esp.tex). Compiled PDFs available. This file is a structured extraction for agent context.

## Contact

- **Email:** ignacio@randazzo.ar
- **Phone:** +54 3517347733
- **Location:** Cordoba, Argentina
- **Personal site:** https://randazzo.ar
- **Project site:** https://i.ar
- **LinkedIn:** https://www.linkedin.com/in/randazzo-ignacio/
- **GitHub:** https://github.com/randazzo-ignacio

## Summary

Security researcher and embedded systems engineer with 8+ years across ASIC digital design, Linux infrastructure administration, vulnerability research, and embedded development. Currently building AI-assisted security audit tooling and reproducible assessment pipelines at Maxwell Security. Previously designed production RTL for multi-million-gate fiber optic ASICs at Marvell Technology. Active CTF competitor and bug bounty researcher. Combines hardware-level understanding with software and infrastructure expertise to identify threats specialists miss.

## Technical Skills

- **Languages:** C, C++, Python, Bash, Ruby, SystemVerilog, VHDL, Emacs Lisp, Verilog
- **Security:** Vulnerability research, security auditing, container hardening, attack surface reduction, CTF, bug bounty
- **Infrastructure:** Linux (Fedora, AlmaLinux), Ansible, Docker/Podman, WireGuard, Caddy, Nginx, Prometheus, Grafana, systemd, SELinux
- **Hardware:** ASIC RTL design, FPGA development, Verilog/VHDL, KiCAD, PCB design, timing closure, simulation, synthesis
- **Tools:** Git, LaTeX, OpenCV, C++ testbenches, Ansible Vault, node_exporter, cAdvisor
- **Languages (spoken):** Spanish (native), English (C2 proficient, near-native)

## Professional Experience

### Security Researcher -- Maxwell Security (2024-2025, Argentina) [PAST ROLE]

- Led vulnerability review and classification for client security assessments, categorizing findings by severity and producing actionable remediation reports.
- Designed and developed AI-assisted audit tooling that accelerated vulnerability discovery and reduced assessment times.
- Built automation pipelines in Python and Bash with fully reproducible Docker/Podman environments, ensuring consistent and verifiable assessment conditions.
- Conducted security research in container hardening, attack surface reduction, and reproducible vulnerability analysis environments.

### ASIC RTL Design Engineer -- Marvell Technology (2021-2023, Argentina remote)

- Designed high-speed coherent digital logic for fiber optic ASICs deployed in data center network infrastructure.
- Authored production RTL in SystemVerilog following industry-standard design and verification methodologies.
- Developed C++ simulation testbenches and participated in verification flows, ensuring first-silicon correctness on multi-million-gate designs.
- Collaborated with international design teams across time zones toward tapeout-ready RTL.

### FPGA Research Assistant -- Fundacion Fulgor (2020-2021, Cordoba, Argentina)

- Designed and verified a dynamically reconfigurable communication channel on FPGA for DSP emulation, enabling rapid protocol testing without silicon refabrication.
- Implemented full RTL design flow in Verilog/VHDL: simulation, synthesis, timing closure, and hardware verification.
- Worked closely with DSP researchers to translate algorithmic requirements into hardware implementations.

### Linux Systems Administrator -- CIII UTN FRC (2017-2021, Cordoba, Argentina)

- Managed deployment, security hardening, and ongoing administration of the research center's Linux server infrastructure, supporting 20+ researchers.
- Contributed to computer vision research projects using OpenCV and Python for medical image analysis as part of a multidisciplinary team.
- Maintained reproducible system configurations and automated deployment procedures.

### Security Auditor & Linux Consultant -- DIUCCO Electronic Voting Project (2019, Argentina)

- Conducted comprehensive security audit of a Linux-based electronic voting system, identifying critical vulnerabilities in access control, kernel configuration, and service exposure.
- Delivered formal audit reports to stakeholders with actionable remediation proposals and risk assessments.
- Implemented all recommended security hardening measures: kernel configuration changes, access controls, and service minimization.

### Embedded Linux Developer -- Hospital de Cordoba Animal Facility (2018, Cordoba, Argentina)

- Developed an embedded Linux system for a smart laboratory scale used in biomedical research, enabling automatic data logging and remote monitoring.
- Wrote custom C drivers and a hardware interface layer to communicate embedded Linux with proprietary sensor hardware, reducing manual measurement by 80%.

## Projects

### i.ar -- Inteligencia Avanzada Randazzo

- **Repo:** https://github.com/randazzo-ignacio/i.ar
- Designed and built an autonomous AI operating environment: a containerized Emacs agentic workspace running on local hardware, powered by local LLMs via Ollama, with no cloud dependencies or telemetry.
- Implemented a multi-agent delegation system in Emacs Lisp where AI agents can spawn specialized sub-agents (coder, reviewer, researcher, security auditor) with depth-limited recursion and context isolation.
- Built complete infrastructure-as-code with Ansible: WireGuard mesh network between 3 cloud servers and 2 local machines, Caddy reverse proxy, Prometheus + Grafana monitoring stack, and automated Ollama inference service deployment.
- Containerized the Emacs environment in a hardened Podman container with Fedora base image, preflight security audit scripts, and restricted networking.
- Developed 17 Emacs Lisp modules (filesystem tools, code execution, agent loading, memory summarization, session persistence, audit logging, file guard) with 106 ERT tests and code coverage reporting.

## Education

### Electronic Engineering (B.Sc.) -- UTN (Universidad Tecnologica Nacional), Cordoba (2015-2025)

- Comprehensive program: digital and analog electronics, PCB design, RF communications, power electronics, embedded systems, computer architecture.
- GPA: 8/10 (honors level). Specialization in digital design and computer architecture.

### English Studies -- C2 Proficient -- IICANA (2003-2013)

- Ten years of formal English education. Certificate and University of Michigan exam. Near-native proficiency.
- Certificates: https://cv.i.ar/certs/iicana.png, https://cv.i.ar/certs/michigan.png

## Speaking

- **ekoparty 2024:** "FPGAs for Password Hash Cracking" -- showcased FPGA power efficiency for hash cracking, with performance near GPU levels and power draw comparable to an Arduino.
- **ekoparty 2025 (submitted):** "The Human Is the Bottleneck: Building AI Security Agents in 10 Days" -- day-by-day account of building i.ar, including container escape incident, upstream gptel bugfix, and autonomous CTF results.

## Other Activities

- Active CTF competitor -- multiple competitions, solving challenges in web exploitation, reverse engineering, and cryptography.
- Bug bounty researcher -- reconnaissance and vulnerability assessment on live targets, including subdomain enumeration, API key exposure, and S3 misconfiguration findings.
- Open-source contributor -- all i.ar infrastructure and tooling is publicly available on GitHub.

## Notes

- CV available in English (cv-eng.tex) and Spanish (cv-esp.tex). Both compiled to PDF.
- LaTeX sources at `~/iar-workspace/cv/` with a template (cv.tex.template) based on Jan Kuster's MIT-licensed CV template.
- Profile photo at `~/iar-workspace/cv/profile.jpg`.
- Compile script at `~/iar-workspace/cv/compile.sh`.