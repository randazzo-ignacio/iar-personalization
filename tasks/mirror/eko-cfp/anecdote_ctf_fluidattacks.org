# Anecdote: CTF Domination -- 20/22 Flags Autonomous (Fluid Attacks CTF)

## The Story

I participated in a CTF (Fluid Attacks CTF) which allowed AI-assisted tools. I thought it was the perfect place to test agent delegation, so I built the ctfwizard agent -- which exists to this day.

I normally achieve 5 or 6 flags in the CTFs I participate in. In this one, I let the AI do *everything* autonomously, without user input except for pasting the challenge descriptions, target URLs, and giving it the needed downloaded files. It achieved 20/22 flags (2095 out of 2735 points), placing 44th.

To this day, I can't reproduce some of the hard challenges even with the writeup it gave me side by side.

## Blog Post (Published)

I built an AI agent in emacs (https://i.ar) that competes in Capture The Flag security competitions. It just placed 44th in Fluid Attacks CTF, solving 20 of 22 challenges autonomously -- 2095 out of 2735 points.

Some challenges were solved in under 2 minutes.

No cloud APIs. No external models. The entire system runs locally on my homelab -- an Emacs-based agentic environment powered by Ollama, hardened inside a Podman container on Fedora Silverblue with SELinux. The agent reads source code, writes exploits, interacts with remote services, and iterates on failures, all on its own.

Here is what surprised me:

The agent didn't just find easy bugs. It tackled graduate-level cryptography and advanced binary exploitation -- categories that require deep mathematical reasoning and low-level systems knowledge.

### ECDSA Private Key Recovery via Lattice Attack

The challenge had a biased nonce (`k >> 8`, zeroing the top 8 bits). The agent identified the Hidden Number Problem, collected 60 signatures, constructed a scaled lattice with a critical 2^8 balancing factor, ran LLL reduction + CVP, and recovered the full 256-bit private key. Then forged an admin signature and grabbed the flag. This is the same class of attack that broke the PS3 and Android Bitcoin wallets.

### Heap Exploitation with House of Apple 2

An integer truncation in a 32-bit alignment calculation turned a 32-byte allocation into a 65,536-byte heap overflow. The agent set up a predictable heap layout, leaked libc and heap addresses via unsorted bin pointers, poisoned tcache entries (handling glibc 2.32+ safe-linking XOR encoding), wrote a fake IO_FILE structure, and triggered `system(" sh")` through `_IO_flush_all_lockp` during `exit()`. On glibc 2.39 with PIE, Full RELRO, NX, stack canary, FORTIFY, SHSTK, and IBT all enabled.

### The "Easy" Stuff (In Seconds)

YAML deserialization RCE, mass assignment privilege escalation, case-sensitive coupon deduplication bypass, hardcoded API key extraction from decompiled APKs, insecure WebView JavaScript bridges, TOCTOU race conditions in banking apps, SHA-256 length extension attacks, and more.

## Evidence

- Writeups: https://github.com/randazzo-ignacio/fluidattacks_writeup
- CTF result: 44th place, 20/22 flags, 2095/2735 points
- The agent operated autonomously -- user only provided challenge descriptions, target URLs, and downloaded files.

## Why This Matters for the Talk

This story proves the framework isn't a toy. It's a force multiplier.

1. **3x personal best.** Nacho normally gets 5-6 flags. The agent got 20. That's not a marginal improvement -- it's a category change. The same human, with the same knowledge, but with an agent that can work through 22 challenges across 5 categories simultaneously.

2. **Graduate-level reasoning.** The ECDSA lattice attack and the House of Apple 2 heap exploitation are not script-kiddie challenges. They require deep mathematical reasoning and low-level systems knowledge. The agent didn't just find low-hanging fruit -- it solved the hard problems.

3. **The human can't reproduce the results.** "I can't reproduce some of the hard challenges even with the writeup it gave me side by side." This is the most powerful line in the story. The agent isn't just faster than the human -- in some cases, it's *better*.

4. **Fully local.** No cloud APIs, no external models. This is the local-first philosophy proven in competition. The entire system runs on a homelab with an RTX 3080.

5. **Autonomous.** The user pasted challenge descriptions and walked away. The agent did everything else.

## Talk Potential

Strong candidate. This is the "proof" section of the talk -- after the container escape story (the danger) and the gptel bugfix (the surprise), this is the payoff: the tool actually works, and it works better than the human who built it.

The two technical highlights (ECDSA lattice attack, House of Apple 2) are perfect for a security audience. ekoparty attendees know what those attacks are. Showing that an AI agent executed them autonomously is genuinely impressive.

The "I can't reproduce it even with the writeup" line is a talk moment. Let it land.

## Key Quote (for slides)

"I normally get 5 or 6 flags in a CTF. The agent got 20. And I can't reproduce some of the hard ones even with the writeup it gave me. The tool isn't replacing security engineers -- it's multiplying them."

## Notes

- The CTF allowed AI-assisted tools, so this wasn't cheating -- it was the intended use case.
- The ctfwizard agent was built specifically for this CTF and still exists in i.ar today.
- The writeup repo is public and can be referenced or linked in the talk.
- The blog post text above is published and can be quoted or adapted for the talk.
- The 2-minute solve times for easy challenges show the speed advantage of autonomous iteration.
- The range of challenge types (crypto, pwn, web, mobile, misc) shows the agent's versatility.