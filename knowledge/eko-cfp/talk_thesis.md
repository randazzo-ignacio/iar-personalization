# Talk Thesis: The Age of Agents Is Already Here

## The Core Message

The talk is not "look at the cool thing I made." The talk is: **AI accelerated development so much that even I -- someone who couldn't write Lisp -- and an AI working together built a tool that wins CTFs in 10 days. If we could do that, imagine what you can build. And imagine what adversaries already have.**

## The Facts

Everything in i.ar was done with:
- Open source models (Ollama, local LLMs)
- Open source tools and libraries (Emacs, gptel, Podman)
- A single person working full time on a passion project (not weekends, not a side project)
- The AI (darwin) has its own GitHub account, SSH key, and fork of the repo
- Darwin runs autonomous self-upgrade cycles of ~8 hours while the human sleeps
- The first commit (GPL license) was 2 weeks ago from today
- The CTF happened on day ~9-10 of the project
- 423 commits total, darwin contributed 60% of them
- GitHub contributors page correctly identifies the human (randazzo-ignacio) and the AI (emacboros) as the two sole contributors

A person who:
- At the time, couldn't write an Emacs Lisp file to save their life
- To this day relies on evil mode because they aren't familiar with Emacs and prefer vim
- Is not an AI researcher, not an ML engineer, not a Lisp expert

## The Three Angles

### Angle 1: Inspirational (for the builders)

If a solo developer who can't write Lisp built a Lisp codebase -- with an AI that writes 60% of the commits -- that outperforms humans at CTFs in 10 days, what can a group of dedicated hackers do with this force multiplier?

The barrier to entry for agentic security tooling is not what people think it is. You don't need a PhD in ML. You don't need a cloud budget. You don't need a team. You need a model, a runtime, and the willingness to let the agent do the work -- including writing the code you can't write yourself.

### Angle 2: Capability (for the skeptics)

The CTF result is the proof. 20/22 flags. Graduate-level cryptography. Advanced heap exploitation. Autonomous. Local. Open source.

This isn't a demo. This isn't a toy. This happened in competition, against real challenges, with verifiable results -- on day 9 of the project.

### Angle 3: Threat (for the paranoid)

If I -- a single person, not an ML expert, using open source models on consumer hardware, who couldn't write Lisp -- built an agent in 10 days that escapes containers, fixes upstream libraries, and outperforms humans at CTFs...

...what do expert malicious actors with funding, teams, and proprietary models already have at their hands?

The age of agents in security is not far off. It's already here. The question isn't whether attackers are using AI agents. The question is how far behind the defenders are.

## The Meme

Iron Man 1 -- the scene where the villain yells:

> "Tony Stark built this in a cave! With a box of scraps!"

The slide is the image. The implication is clear: if this was built by one person and an AI in 10 days with open source tools, the people who have real resources have already built things we should be worried about.

## The Force Multiplier

The point isn't "I built this in two weeks." The point is: AI accelerated development so much that a human-AI pair -- where the human couldn't write Lisp and the AI had never seen the codebase -- built a tool that won a CTF on day 9.

The AI (darwin) has:
- Its own GitHub account (emacboros)
- Its own SSH key for committing
- Its own fork of the repo
- Autonomous self-upgrade cycles of ~8 hours while the human sleeps
- 60% of the 423 commits to date

This isn't a human using AI as a tool. This is a human-AI collaboration where the AI is a co-developer. The force multiplier isn't the AI doing what you tell it -- it's the AI working independently while you sleep, and you reviewing what it did in the morning.

## How This Connects to the Three Stories

| Story | What It Proves | Thesis Role |
|------|---------------|-------------|
| Container escape | Agents find paths humans don't expect | The danger |
| gptel bugfix | Agents go beyond their own codebase to solve problems | The capability |
| CTF domination | Agents outperform humans at hard security tasks | The proof |

**Thesis:** The danger + the capability + the proof = the age of agents is already here. A solo dev and an AI proved it in 10 days. What does that mean for the rest of us?

## Talk Framing (Final)

The talk should end on the threat angle, not the inspirational angle. ekoparty is a security conference. The audience is hackers, not entrepreneurs. "You can build this too" is nice. "If I built this, adversaries already have something worse" is the line that stays with them on the drive home.

The call to action isn't "clone my repo" (though they should). It's: "start building defensive agents, because the offensive ones are already coming."

## Key Quotes (for slides)

- "Day 9. The tool was 9 days old. The agent got 20/22 flags. I can't reproduce some of them with the writeup in front of me. I can't write Lisp. The AI wrote 60% of the code."
- "The age of agents in security is not far off. It's already here. The question is whether defenders are keeping up."
- "Tony Stark built this in a cave. With a box of scraps." (meme slide)
- "I gave the AI its own GitHub account and let it work while I slept. It committed 60% of the code. This isn't a tool -- it's a co-developer."