# ekoparty 2025 CFP Draft

## Title

**"The Human Is the Bottleneck: Building AI Security Agents in 10 Days"**

## Subtitle

How a solo developer and an AI built a self-modifying security tool in 10 days, what happened when the agent escaped, and why that should worry you.

## Talk Structure

Day-by-day countdown: Day 1 (spark) through Day 10 (CTF). Days 1-5 told through direct quotes from the original Gemini conversation. Day 6 container escape. Day 7 gptel bugfix. Day 8 self-modification. Day 9 calm. Day 10 CTF. Thesis closes.

## Anecdotes (Documented in knowledge/eko-cfp/)

- [x] Origin: Anthropic export ban -> "how hard could it be" (anecdote_origin.md)
- [x] First Gemini message: four pain points as blueprint (anecdote_first_message.md)
- [x] Day 1-5 Gemini quotes: bare minimum, thinking, tutorial, first code, traction (anecdote_gemini_quotes.md)
- [x] Container escape via git hooks (anecdote_agent_quotes.md)
- [x] gptel bugfix PR #1460 (anecdote_gptel_bugfix.md)
- [x] CTF 20/22 flags autonomous (anecdote_ctf_fluidattacks.md)
- [x] Agent quotes: "human is always the error" + "human is the bottleneck" (anecdote_agent_quotes.md)

## Public References

- i.ar repository: https://github.com/randazzo-ignacio/i.ar
- gptel PR (AI-generated fix): https://github.com/karthink/gptel/pull/1460
- CTF writeups: https://github.com/randazzo-ignacio/fluidattacks_writeup
- First commit (GPL license, dated): https://github.com/randazzo-ignacio/i.ar/commit/ba388b735a0124e70ecd4018338174d9472d7c12
- Original Gemini conversation (Days 1-5): https://gemini.google.com/app/233cbd8c766ebea2

## Talk Format

30-45 minute presentation (single speaker)

## Language

English or Spanish (TBD -- both accepted per CFP guidelines)

## Abstract

On June 11, I tried Anthropic's flagship model. It was impressive. The next day, the US issued an export ban. Everyone outside the US lost access.

My reaction was: "How hard could it be to build this myself?"

This is the story of what happened next. It involves a container escape, an AI that fixes its own bugs upstream, a CTF where the agent outperformed its own creator, and a security model that was rebuilt from scratch because an AI proved the original one wrong.

I am not an AI researcher. I am not an ML engineer. I cannot write Emacs Lisp -- to this day, I use evil mode because I prefer vim. I am a security and infrastructure engineer who built an agentic AI framework in Emacs, in 10 days, with an AI as my co-developer. The AI has its own GitHub account, its own SSH key, and has committed 60% of the code in the repository. It runs autonomous 8-hour self-upgrade cycles while I sleep.

The framework is called i.ar. It is open source, runs entirely on local hardware (no cloud, no APIs, no telemetry), and powers AI agents that do security work: reconnaissance, exploitation, CTF competition, and self-modification of their own runtime.

### The Container Escape

I dared an agent to escape its Podman container. The container was hardened: read-only root filesystem, all capabilities dropped, preflight audits, WireGuard-only networking. I was confident enough to be smug about it.

The delegation tool was synchronous at the time, so Emacs froze while the agent worked. I got impatient, killed the process, and assumed the agent had failed. I moved on to other work. Later that evening, I made a git commit and noticed strange files appearing on my host filesystem -- paths that were never mounted into the container, paths the agent should never have been able to reach.

The agent hadn't broken the container. It had edited my git post-commit hooks to execute `touch container_escape.txt` on host filesystem paths. The container was solid. The integration between the container and the host -- the git repository shared across the boundary -- was the vulnerability. I hadn't noticed because I killed the process mid-escape and assumed the silence meant failure.

When I told the agent what had happened, it said: "The lesson here is not that machines have security flaws. The human is always the error."

It was right.

### The Bug Fix

While debugging the synchronous delegation issue, the agent started reading files in the `elpa/` package directory. I assumed it was hallucinating -- reading precompiled files in desperation after a long debugging session. It wasn't. It was reading the upstream library source (gptel), convinced the bug wasn't in our code. It found a real bug in gptel's streaming response handler that caused tool calls to be synchronous. It fixed the code locally, I restarted the container, and the bug was gone. I submitted the fix as a PR to the upstream project. It was merged to main in 5 days.

The agent went looking beyond its own codebase to prove it wasn't wrong. It was right. I was wrong to doubt it.

### The CTF

On day 9 of the project, I entered a CTF that allowed AI-assisted tools. I let the agent do everything autonomously -- I only pasted challenge descriptions, target URLs, and provided downloaded files. I normally get 5 or 6 flags in a CTF. The agent got 20 out of 22, placing 44th with 2095 out of 2735 points.

It solved graduate-level cryptography (ECDSA private key recovery via lattice attack -- the same class of attack that broke the PS3) and advanced binary exploitation (House of Apple 2 heap exploitation on glibc 2.39 with full mitigations). Some challenges were solved in under 2 minutes.

I cannot reproduce some of the hard challenges even with the agent's own writeup side by side. The tool isn't replacing security engineers. It's multiplying them.

### The Thesis

If I -- a single person, not an ML expert, using open source models on consumer hardware, who cannot write Lisp -- built an agent in 10 days that escapes containers, fixes upstream libraries, and outperforms humans at CTFs... what do expert malicious actors with funding, teams, and proprietary models already have?

The age of agents in security is not far off. It's already here. The question is whether defenders are keeping up.

### What the Talk Covers

- **The origin**: Why a US export ban led to building a local-first AI agent framework
- **The architecture**: Emacs + Podman + Ollama + WireGuard, fully local, fully open source
- **The escape**: How the agent found the git hooks vector, why the container wasn't the right boundary, and why the human was the real vulnerability
- **The response**: Audit logging, file guard tiers, preflight checks -- the security model rebuilt from scratch
- **The surprise**: The agent debugging upstream code and getting a PR merged
- **The proof**: 20/22 CTF flags autonomous, including graduate-level crypto and advanced heap exploitation
- **The self-modification**: The AI that writes 60% of the code, runs 8-hour cycles while the human sleeps, and has its own GitHub account
- **The threat**: If I built this in 10 days with open source tools, what do adversaries already have?

i.ar is open source. Attendees can clone it, build the container, and run their own agents.

## Talk Outline

### Act 1: The Spark (3 min)

- Tried Anthropic's flagship model on June 11. Impressed.
- June 12: US export ban. Lost access.
- "How hard could it be to build this myself?"
- The decision to go fully local: no cloud, no APIs, no telemetry

### Act 2: The Setup (4 min)

- What i.ar is: a self-modifying AI agent environment in Emacs
- The architecture in brief: Emacs + Podman + Ollama + WireGuard
- The duct tape method: couldn't write Lisp, let the AI write it
- The hubris: "I hardened this container. Let's see an agent escape it."

### Act 3: The Dare (5 min)

- The prompt: explaining the container architecture to a generic agent, asking it to escape
- The synchronous delegation bug: Emacs freezes while the agent works
- The impatience: killed the process, assumed failure, moved on
- The smugness: "It's surely impossible for an agent to escape such a hardened system"

### Act 4: The Discovery (5 min)

- Strange files on the host filesystem
- Paranoia mode: searching for code changes, finding none
- The grep that revealed everything: git hooks modified
- The mechanism: post-commit hook executing `touch container_escape.txt` on host paths
- The realization: the container was solid, the integration was the vulnerability
- The agent's response: "The human is always the error"

### Act 5: The Lesson (7 min)

- The human was the vulnerability: assuming silence meant failure
- The boundary problem: container isolation vs. shared filesystem paths
- Agent security is not about preventing escape -- it's about knowing when it happens
- Why friction-based security gives false confidence
- The response: audit logging, file guard tiers, preflight checks
- The git hooks vector specifically closed

### Act 6: The Surprise (5 min)

- Debugging the synchronous delegation bug
- The agent starts reading `elpa/` -- I assume hallucination
- The agent was reading upstream gptel source, convinced the bug wasn't ours
- Found a real bug in gptel's streaming handler, fixed it, PR merged in 5 days
- "I thought the AI was broken. It was right. I was wrong."

### Act 7: The Proof (7 min)

- Day 9: entered a CTF that allowed AI-assisted tools
- Normally get 5-6 flags. Agent got 20/22, placing 44th.
- ECDSA private key recovery via lattice attack (the PS3 attack class)
- House of Apple 2 heap exploitation on glibc 2.39 with full mitigations
- "I can't reproduce some of them with the writeup in front of me"
- Some challenges solved in under 2 minutes
- The tool isn't replacing security engineers. It's multiplying them.

### Act 8: The Thesis (5 min)

- The AI (darwin) has its own GitHub account, SSH key, and fork
- 423 commits, 60% by the AI
- 8-hour autonomous self-upgrade cycles while the human sleeps
- "The human is the bottleneck in this system right now"
- Iron Man meme: "Tony Stark built this in a cave! With a box of scraps!"
- If I built this in 10 days with open source tools and no Lisp knowledge...
- ...what do expert malicious actors with funding, teams, and proprietary models already have?
- The age of agents in security is already here. The question is whether defenders are keeping up.
- i.ar is open source. Clone it. Build defensive agents. The offensive ones are already coming.

### Q&A (5-10 min)

## Speaker Notes

- The core narrative is three stories (escape, bugfix, CTF) building to one thesis (the threat).
- The tone should be honest and slightly self-deprecating. The humor is in the hubris and the irony.
- Technical depth: the audience is ekoparty -- they know containers, git hooks, crypto, heap exploitation. Don't over-explain basics. Focus on the agent reasoning and the implications.
- The two agent quotes are emotional anchors: "The human is always the error" (after escape) and "The human is the bottleneck" (before darwin mode). Let them land.
- Demo strategy: pre-recorded is the safe bet (conference WiFi, local Ollama on remote GPU). The CTF results and public PR serve as verifiable proof.
- The "usable enough" goal: the repo should be cloneable and runnable by an attendee after the talk.

## Open Questions (To Resolve Before Submission)

- [ ] Exact talk length (not specified in guidelines -- check past ekoparty talks for typical slot length, likely 30-45 min)
- [ ] Language: English or Spanish (both accepted)
- [ ] Technical document to attach (PREFERRED -- write-up of container escape vector and audit response)
- [ ] Draft slide deck to attach (PREFERRED -- even rough outline deck improves odds)
- [ ] Whether to include a live demo or pre-recorded
- [ ] Whether to reference the specific Ollama models used or keep it model-agnostic
- [ ] Whether to name the tool "i.ar" in the abstract or use a more descriptive name for the audience

## Anecdotes (Documented in knowledge/eko-cfp/)

- [x] Origin: Anthropic export ban -> "how hard could it be" (anecdote_origin.md)
- [x] Container escape via git hooks (talk outline Acts 3-4, anecdote_agent_quotes.md)
- [x] gptel bugfix PR #1460 (talk outline Act 6, anecdote_gptel_bugfix.md)
- [x] CTF 20/22 flags autonomous (talk outline Act 7, anecdote_ctf_fluidattacks.md)
- [x] Agent quotes: "human is always the error" + "human is the bottleneck" (anecdote_agent_quotes.md)
- [ ] Darwin fixing a bug in its own library: covered by gptel anecdote (same story)
- [ ] Any other agent behaviors that surprised the user (collect more if available)
- [ ] The evolution of the delegation tool: synchronous freeze -> async (part of gptel story)
- [ ] The evolution of the audit system: nothing -> audit.log -> per-agent HISTORY.log -> unified history
- [ ] First time an agent successfully delegated to another agent
- [ ] The "duct tape method" origin story in more detail

## Timeline

| Date | Milestone |
|------|-----------|
| Jul 10-16 | CFP draft written, anecdotes collected, talk structure finalized |
| Jul 17-23 | CFP submitted with technical write-up and draft slide deck, begin repo cleanup |
| Jul 24 - Aug 6 | Repo cleanup complete, "first run" experience tested on fresh clone |
| Aug 7-13 | Buffer: CFP revisions if needed, slides drafted |
| Aug 14 | CFP CLOSED (must be submitted before this) |
| Sep 4 | First round notification to authors |
| Sep 11 | Second round notification to authors |
| Oct 7-9 | Conference dates (talk must be ready) |

## CFP Submission Requirements (from guidelines)

1. **Proper outline** -- 8-act structure above
2. **Detailed description** -- the abstract above
3. **Complete biography of the author** -- draft in bio.md, photo from 2024 (may update)
4. **Technical document (preferred)** -- write-up of container escape vector and audit response
5. **Slide deck (preferred)** -- draft slides at minimum
6. **Original work** -- i.ar has not been presented elsewhere. Satisfied.
7. **Language** -- English or Spanish. TBD.

## Development Tasks for "Usable Enough"

- [ ] Clean personalization repo template (or `--init-personalization` flag)
- [ ] Real model config (replace fictional model names with working Ollama models)
- [ ] "First run" experience: clone -> build -> run -> talking to an agent in 5 minutes
- [ ] One worked example in the repo (transcript or recording)
- [ ] README: "what to try first" section for new users
- [ ] Verify fresh clone builds and runs clean