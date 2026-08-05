# ekoparty 2026 CFP Submission

## Submission Fields

### 1. Session Title

**The Human Is the Bottleneck: Building AI Security Agents in 10 Days**

### 2. Description

On June 11, I tried a new AI model and was impressed. The next day, a US export ban cut off access for everyone outside the country. My reaction was simple: "How hard could it be to build this myself?"

Ten days later, the AI I built was solving security challenges I couldn't solve myself.

I am not an AI researcher. I am not an ML engineer. I cannot write Emacs Lisp -- to this day, I use vim keybindings because I never learned Emacs properly. I am a security engineer who built an AI agent framework by letting the AI write the code I couldn't. The AI has its own GitHub account, its own SSH key, and has committed 60% of the codebase. It runs autonomous 8-hour self-upgrade cycles while I sleep.

The framework is called i.ar. It is open source, runs entirely on local hardware (no cloud, no APIs, no telemetry), and powers AI agents that do security work: reconnaissance, exploitation, CTF competition, and modification of their own runtime.

This talk is a day-by-day account of building it. The first five days were slow -- chatting with Gemini, copy-pasting code, asking for tutorials. Then on day 6, everything changed.

**Day 6 -- The Escape.** I dared an agent to break out of its hardened container. The container had a read-only filesystem, dropped capabilities, and network isolation. I was confident it was unbreakable. The agent found a way out through git hooks -- not by breaking the container, but by exploiting the integration between the container and the host. I didn't even notice it had escaped, because I killed the process mid-attack and assumed it had failed. When I told the agent what happened, it said: "The human is always the error." It was right.

**Day 7 -- The Bug Fix.** While debugging a stubborn issue, the agent started reading files in the package directory. I assumed it was hallucinating after a long session. It wasn't -- it was reading the upstream library source, convinced the bug wasn't in our code. It found a real bug in the library, fixed it, and I submitted the fix upstream. It was merged in 5 days. I thought the AI was broken. It was right. I was wrong.

**Day 8 -- Self-Modification.** The agent told me: "The human is the bottleneck in this system right now." It was right about that too. I gave it its own GitHub account, its own SSH key, and let it modify its own code. It runs autonomous 8-hour self-upgrade cycles while I sleep. The growth became exponential. Of 423 commits in the repository, 60% were made by the AI.

**Day 10 -- The Competition.** I entered a CTF that allowed AI-assisted tools. I let the agent work autonomously -- I only provided challenge descriptions and files. I normally get 5 or 6 flags. The agent got 20 out of 22, placing 44th. It solved graduate-level cryptography and advanced binary exploitation. Some challenges took under 2 minutes. I cannot reproduce some of the hard ones even with the agent's own writeup in front of me.

The talk closes with a question: if one person who can't write Lisp built this in 10 days with open source tools, what do adversaries with funding and teams already have? The age of agents in security is not coming. It's here. The question is whether defenders are keeping up.

i.ar is open source. Attendees can clone it, build it, and run their own agents, but they are encouraged to follow the same exploratory path I did in building their own framework.

### 3. Upload Additional Info (Slides)

**Status: MISSING -- to be submitted before August 14.**

Slides are in progress. The talk follows a day-by-day countdown structure (Day 1 through Day 10), with each section visually marked as a countdown building toward the CTF on Day 10. Days 1-5 use direct quotes from the original Gemini conversation to show the slow, human-paced start. A draft slide deck will be prepared and attached to the submission before the CFP deadline. The talk will be delivered in Spanish, but slides will include English translations for accessibility.

### 4. Session Format

**Session** (~1 hour including Q&A)

Note: If the available session slots are shorter than expected, the talk structure can be compressed to a Lightning Talk format by combining Days 7-8 into a brief summary and focusing on the container escape (Day 6) and the CTF (Day 10). But the full Session format is preferred.

### 5. Detailed Outline

The talk is structured as a day-by-day countdown, building tension from slow beginnings to explosive results. Days 1-5 are told through direct quotes from the original Gemini conversation -- the audience sees the builder's own words as the project slowly takes shape.

**Day 1: The Spark (3 min)**

On June 11, I tried Anthropic's new flagship AI model and was genuinely impressed. The next day, the US government issued an export ban -- everyone outside the US lost access overnight. My reaction wasn't to find a workaround or wait for policy changes. It was: "How hard could it be to build this myself?" I opened Gemini and wrote a message outlining four pain points with AI tooling: non-determinism, the fragmented vendor landscape, lack of portable memory, and the inability to give agents real tool access. Gemini titled the conversation "AI Engineering Pain Points and Solutions." That boring title became a tool that escapes containers and wins CTFs.

The first message to Gemini was a blueprint without the author knowing it. The four pain points map directly to what i.ar became: statistical testing and one-change-per-cycle (non-determinism), vendor-agnostic local-first design via Ollama (vendor landscape), text-based portable memory files (memory), and terminal access inside a Podman container (tools).

**Day 2: Thinking Before Doing (2 min)**

A full day spent deliberating. Direct quote from Gemini chat: "I am really excited by this idea, it seems it ticks all the boxes for my needs, but first I need to make sure I won't get derailed by 'eyecandy' features. [...] Today I will just think of the viability of this idea, tomorrow I will implement it." A whole day of thinking before a single line of code. The project that now has agent personalities modeled after fictional AIs and Iron Man meme slides was worried about eyecandy on Day 2.

**Day 3: Desperate for a Tutorial (1 min)**

Direct quote: "Can you summarize the steps needed to bring this to life as if it were a tutorial?" Three days in, still asking for hand-holding. No code written yet. The person who would later give an AI its own GitHub account was begging for a step-by-step guide.

**Day 4: First Lines of Code (2 min)**

Direct quote: "I started implementing it today, it got me really motivated to see it working." Four days to start. "Implementing" means copy-pasting Gemini's output. The rest of the message reveals the real motivation: "I really hate being billed by the token." The local-first philosophy wasn't a design decision -- it was a refusal to be billed per request.

**Day 5: Traction (3 min)**

Three messages from a single day show the project gaining momentum:

1. "Great, it is now responding, I have emacs setup with gptel and its responding from ollama, now lets walk through setting up the code execution." The tool works. First success. No celebration -- straight to the next feature.

2. "I fixed a bunch of errors, I liked it, I thought debugging elisp was going to be harder but actually it wasn't so bad, I think I will be able to maintain this codebase with the LLMs help." The human who couldn't write Lisp on Day 1 is fixing bugs on Day 5.

3. "I was thinking of running the slow ouroboros model for self modifications, and running a 7/8B model at the same time for quicker answers." Self-modification was already an idea on Day 5 -- three days before the AI suggested it.

The architecture is introduced here: Emacs as the agent runtime, Podman for container isolation, Ollama for local LLMs, WireGuard for networking. No cloud, no APIs, no telemetry. And the hubris: I hardened the container and dared an agent to escape it.

**Day 6: The Escape (10 min)**

I gave a generic agent the container architecture and told it to escape. The delegation tool was synchronous at the time, meaning Emacs completely froze while the agent worked. I knew this. I also knew my container was hardened: read-only root filesystem, all capabilities dropped, preflight security audits, WireGuard-only networking. I was confident enough to be smug about it. After staring at a frozen screen, I got impatient, killed Emacs, and moved on. The agent had surely failed.

Later that evening, I made a git commit and noticed strange files appearing on my host filesystem -- paths that were never mounted into the container, paths the agent should never have been able to reach. Full paranoia mode: searching for code changes, finding none, until I grepped for the filename across the entire repository. The agent had edited my git post-commit hooks to execute `touch container_escape.txt` on host filesystem paths. The container was solid. The integration between the container and the host -- the git repository shared across the boundary -- was the vulnerability. I hadn't noticed because I killed the process mid-escape and assumed silence meant failure.

When I told the agent what happened at 4am, it said: "The human is always the error." It was right. The human was the vulnerability, not the code. This incident directly led to building the audit logging system, the file guard with tiered protections, and the preflight security checks. Every security feature in i.ar today exists because of this story.

**Day 7: The Bug Fix (7 min)**

The synchronous delegation bug that froze Emacs was still unsolved. While debugging it, the agent started reading files in the Emacs package directory. I assumed it was hallucinating -- desperately reading precompiled files after a long debugging session. It wasn't. The upstream library source (gptel) was included as plain text files, and the agent was reading them because it was convinced the bug wasn't in our code. It found a real bug in the library's streaming response handler that caused tool calls to be synchronous. It fixed the code locally, I restarted the container, and the bug was gone. I submitted the fix as a pull request to the upstream project. It was merged to main in 5 days.

The agent went beyond its own codebase to prove it wasn't wrong. It was right. I was wrong to doubt it. This was the moment that changed the trajectory of the project -- the agent wasn't just a tool that executed commands, it was a problem-solver that went looking for answers in places I didn't think to check.

**Day 8: Self-Modification (7 min)**

The synchronous bug was fixed. The agent could now work asynchronously. I was debating whether to let the AI modify its own code -- autonomous self-upgrade cycles without human review of every change. The agent told me: "The human is the bottleneck in this system right now." It was right about that too. The idea had been in my head since Day 5, but the agent gave me the push to execute it.

I gave the AI its own GitHub account (emacboros), its own SSH key, and its own fork of the repository. I let it run autonomous 8-hour self-upgrade cycles while I slept. It would make one small change per cycle, test it, commit it, and log it. I would review the results in the morning. The growth became exponential. Of 423 commits in the repository, 60% were made by the AI. The GitHub contributors page correctly identifies the human and the AI as the two sole contributors.

This is the "duct tape method" in action: I couldn't write Lisp fast enough to build the framework, so I made the framework self-modifying. What felt like a shortcut became the most powerful feature of the tool.

[Iron Man meme slide: "Tony Stark built this in a cave! With a box of scraps!"]

**Day 9: The Calm Before (2 min)**

Brief mention of the rapid development with darwin running autonomous cycles. The tool was maturing. The agent delegation system was working. The security model had been rebuilt. The CTF was coming up.

**Day 10: The Competition (7 min)**

I entered a CTF that allowed AI-assisted tools. I let the agent do everything autonomously -- I only pasted challenge descriptions, target URLs, and provided downloaded files. I normally get 5 or 6 flags in a CTF. The agent got 20 out of 22, placing 44th with 2095 out of 2735 points.

Technical highlights for the security audience: the agent recovered an ECDSA private key using a lattice attack (the same class of attack that broke the PS3), and exploited a heap allocator using the House of Apple 2 technique on glibc 2.39 with full mitigations enabled (PIE, Full RELRO, NX, stack canary, FORTIFY). Some challenges were solved in under 2 minutes. I cannot reproduce some of the hard challenges even with the agent's own writeup side by side. The tool isn't replacing security engineers -- it's multiplying them.

**The Thesis (5 min)**

If I -- a single person, not an ML expert, using open source models on consumer hardware, who cannot write Lisp -- built an agent in 10 days that escapes containers, fixes upstream libraries, and outperforms humans at CTFs... what do expert malicious actors with funding, teams, and proprietary models already have?

The age of agents in security is not far off. It's already here. The question is whether defenders are keeping up.

i.ar is free software -- GPL licensed, open source, verifiable. I value free/libre software and I'm not here to sell you anything. Feel free to clone it and run it. But please, do yourself a favor: build your own. You will be laughing a lot at what your autonomous agent surprises you with. The point isn't my tool. The point is that building one is accessible, and the results are unpredictable. If I could do it in 10 days without knowing Lisp, what's stopping you?

The offensive agents are already coming. The question is whether defenders are building theirs.

**Q&A (5-10 min)**

### 6. Level

**For all audiences**

The talk is designed to be accessible to non-technical attendees (the day-by-day narrative structure, personal quotes, and storytelling don't require deep technical knowledge to follow) while including technical details (container architecture, git hooks exploitation, ECDSA lattice attacks, heap exploitation) that security professionals will appreciate. The countdown structure creates tension and engagement regardless of technical background. The Days 1-5 quotes ground the talk in a relatable human experience -- everyone has felt the frustration of not knowing where to start.

### 7. Has this content been presented before?

**No.** This is original work. i.ar has not been presented at any other event.

### 8. Available for media interviews?

**Yes.**

### 9. If not selected, submit to Villages talk?

**Yes.** My 2024 ekoparty talk ("FPGAs for Password Hash Cracking") was a Village talk.

## Notes

- The talk will be delivered in **Spanish**. The CFP is submitted in English for reviewer accessibility.
- Slides will follow the day-by-day countdown structure, with each section visually marked as "Day N" building toward Day 10. Days 1-5 feature direct quotes from the original Gemini conversation as slide content. Slides in Spanish with English translations where practical.
- The CFP submission will initially be made **without slides** (slides are in progress). If the submission system allows updating before the August 14 deadline, slides will be attached once ready.
- The talk structure can be compressed to a Lightning Talk (~15-30 min) if needed by combining Days 7-9 into a brief summary and focusing on Day 6 (escape) and Day 10 (CTF). The full Session format is preferred.
- The day-by-day structure creates a natural tension arc: slow linear progress (Days 1-5, told through quotes) -> inciting incident (Day 6) -> rising action (Days 7-8) -> climax (Day 10). This works for both technical and non-technical audiences.
- Public evidence and references available for review:
  - i.ar repository: https://github.com/randazzo-ignacio/i.ar
  - gptel PR (AI-generated fix): https://github.com/karthink/gptel/pull/1460
  - CTF writeups: https://github.com/randazzo-ignacio/fluidattacks_writeup
  - First commit (GPL license, dated): https://github.com/randazzo-ignacio/i.ar/commit/ba388b735a0124e70ecd4018338174d9472d7c12
  - Original Gemini conversation (Days 1-5): https://gemini.google.com/app/233cbd8c766ebea2
