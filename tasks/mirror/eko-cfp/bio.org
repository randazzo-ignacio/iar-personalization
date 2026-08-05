# Speaker Bio: Ignacio "Nacho" Agustin Randazzo

## Draft Bio (for CFP submission)

Ignacio "Nacho" Agustin Randazzo is a security researcher and embedded systems engineer based in Villa Carlos Paz, Córdoba, Argentina. With 8+ years across ASIC digital design, Linux infrastructure administration, vulnerability research, and embedded development, he works across the entire stack -- from silicon to software to security. He believes in understanding systems from the transistor up, and that breadth is not a lack of focus -- it's the ability to see threats and solutions that specialists miss.

He previously built AI-assisted security audit tooling at Maxwell Security (2024-2025), where he designed reproducible assessment pipelines and automation for vulnerability discovery. Before that, he designed production RTL for multi-million-gate fiber optic ASICs at Marvell Technology and managed Linux infrastructure at UTN's research center (CIII). He has conducted security audits of electronic voting systems, developed embedded Linux drivers for biomedical research hardware, and designed dynamically reconfigurable FPGA communication channels for DSP emulation.

Before the LLM era, he worked on neural networks and studied the underlying mathematics. Now he builds agentic systems with local models, focused on security, trust, and sovereignty. His current project, i.ar, is a self-modifying AI operating environment built in Emacs, hardened in Podman, powered entirely by local LLMs -- no cloud, no telemetry, no backdoors. He built it in 10 days without knowing Emacs Lisp; the AI wrote most of the code, including the parts he couldn't.

He is a strong advocate for free/libre software and self-hosted infrastructure. He spoke at ekoparty 2024 on FPGA-based password hash cracking, demonstrating power efficiency near GPU performance at Arduino-level power draw. He returns in 2026 to talk about what happens when you give an AI agent a terminal and let it modify its own code.

He holds a B.Sc. in Electronic Engineering from UTN (Universidad Tecnológica Nacional), Córdoba, with honors-level GPA (8/10) and specialization in digital design and computer architecture. He is C2 proficient in English (University of Michigan certificate, IICANA). He is an active CTF competitor, bug bounty researcher, and open-source contributor.

Personal site: https://randazzo.ar
GitHub: https://github.com/randazzo-ignacio

## Full Background (for reference, not for submission)

### Professional Experience

- **Security Researcher -- Maxwell Security (2024-2025, Argentina):** Led vulnerability review and classification for client security assessments. Designed and developed AI-assisted audit tooling. Built automation pipelines in Python and Bash with reproducible Docker/Podman environments. Conducted security research in container hardening and attack surface reduction.
- **ASIC RTL Design Engineer -- Marvell Technology (2021-2023, Argentina remote):** Designed high-speed coherent digital logic for fiber optic ASICs deployed in data center network infrastructure. Authored production RTL in SystemVerilog. Developed C++ simulation testbenches. Collaborated with international design teams toward tapeout-ready RTL.
- **FPGA Research Assistant -- Fundación Fulgor (2020-2021, Córdoba, Argentina):** Designed and verified a dynamically reconfigurable communication channel on FPGA for DSP emulation. Implemented full RTL design flow in Verilog/VHDL: simulation, synthesis, timing closure, hardware verification.
- **Linux Systems Administrator -- CIII UTN FRC (2017-2021, Córdoba, Argentina):** Managed deployment, security hardening, and administration of the research center's Linux server infrastructure supporting 20+ researchers. Contributed to computer vision research projects using OpenCV and Python.
- **Security Auditor & Linux Consultant -- DIUCCO Electronic Voting Project (2019, Argentina):** Conducted comprehensive security audit of a Linux-based electronic voting system. Identified critical vulnerabilities in access control, kernel configuration, and service exposure. Delivered formal audit reports and implemented all remediation.
- **Embedded Linux Developer -- Hospital de Córdoba Animal Facility (2018, Córdoba, Argentina):** Developed an embedded Linux system for a smart laboratory scale. Wrote custom C drivers and hardware interface layer. Reduced manual measurement by 80%.

### Education

- **B.Sc. Electronic Engineering -- UTN (Universidad Tecnológica Nacional), Córdoba (2015-2025):** Comprehensive program: digital and analog electronics, PCB design, RF communications, power electronics, embedded systems, computer architecture. GPA: 8/10 (honors level). Specialization in digital design and computer architecture.
- **English Studies -- C2 Proficient -- IICANA (2003-2013):** Ten years of formal English education. University of Michigan exam certificate. Near-native proficiency.

### Domains
- Hardware: ASIC, FPGA, RTL design, verification, KiCAD, PCB design, timing closure
- Software: C, C++, Python, Bash, Ruby, SystemVerilog, VHDL, Emacs Lisp (learned by letting AI write it), Verilog
- Infrastructure: Ansible, Podman, WireGuard, Caddy, Nginx, Fedora Silverblue, SELinux, Prometheus, Grafana, systemd
- Security: Vulnerability research, security auditing, container hardening, attack surface reduction, CTF, bug bounty
- AI/ML: Pre-LLM neural networks, now local agentic systems with Ollama + gptel
- Systems: Linux admin, systemd, immutable OS foundations

### Projects
- i.ar: A self-modifying AI operating environment in Emacs, hardened in Podman, powered by local LLMs. Open source. Multi-agent delegation system, 17 Emacs Lisp modules, 106 ERT tests, infrastructure-as-code with Ansible.
- Homelab: Perpetually in flux. Currently: NAS RAID not connected, backups non-existent.
- Domains: randazzo.ar (personal site), i.ar (project site)

### Speaking History
- ekoparty 2024: "FPGAs for Password Hash Cracking" -- showcased FPGA power efficiency for hash cracking, with performance near GPU levels and power draw comparable to an Arduino.
- ekoparty 2026 (submitted): "The Human Is the Bottleneck: Building AI Security Agents in 10 Days" -- day-by-day account of building i.ar, including container escape incident, upstream gptel bugfix, and autonomous CTF results.

### Other Activities
- Active CTF competitor -- multiple competitions, solving challenges in web exploitation, reverse engineering, and cryptography.
- Bug bounty researcher -- reconnaissance and vulnerability assessment on live targets, including subdomain enumeration, API key exposure, and S3 misconfiguration findings.
- Open-source contributor -- all i.ar infrastructure and tooling is publicly available on GitHub.

### Stack
Emacs (with evil mode, because vim is still preferred), gptel, Ollama, Podman, Ansible, WireGuard, Caddy, Fedora Silverblue, SELinux, local hardware (3080 server at 192.168.2.69)

### Philosophy
- Local-first, always. Cloud dependencies mean someone else controls your compute.
- Containment first. Every autonomous capability has a kill switch.
- Human agency. Systems empower individuals, not control them.
- Precision over speed. The cost of a mistake in infrastructure is real.
- The duct tape method. What feels like a shortcut is actually the creative edge. Constraint forces a different path, and the different path is where innovation lives.

## Notes

- The bio needs a photo for submission (guidelines require complete biography).
- The bio should be concise for submission (~200-250 words) but the full background is useful for reference and potential "about the speaker" slide content.
- The "learned Lisp by letting AI write it" angle is worth including -- it reinforces the thesis.
- No longer at Maxwell Security (2024-2025). Current employment status: between jobs (as of mid-2026).
- The draft bio above is ~280 words. For a tighter submission version, the last paragraph (education + English + CTF) can be trimmed to a single sentence.