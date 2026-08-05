# Anecdote: i.ar Fixes Its Own Foundation (gptel PR #1460)

## The Story

Whilst working through a particularly annoying bug trying to finally fix the synchronous process of the tool delegation, both i.ar and myself were scratching our heads trying to find what was wrong with i.ar's code. The delegation code *looked* like it *should* be working asynchronously, but Emacs kept freezing on every delegate call.

At one point in the discussion between me and the LLM, I saw it started reading inside `elpa/`'s folder -- the package directory. I thought surely I had broken the AI. We had been going on for so long that it was trying *anything* it could to fix the bug, and I was ready to let it die and start a new session with a lower context size. I was exhausted, it was exhausted, the problem was surely at its end. I had built an agentic framework in Emacs without knowing Emacs Lisp or even using Emacs daily myself, and if neither I nor the AI could fix a bug this early in the process, this was proof that self-modification was a silly idea.

But I was tired and just wanted to have fun watching the silly LLM hallucinate while reading what I thought were precompiled `.elc` files. Little did I know that gptel's library source, which i.ar is based on, was included as part of elpa's release as plain `.el` files. The LLM was *sure* the bug wasn't in i.ar's code, so it went investigating upstream to prove *it* wasn't wrong -- the foundation I was building upon was flawed, and it knew it.

Lo and behold, it found a bug in `gptel-request.el` streaming responses that caused tool calls to be synchronous when they were seemingly already async. It made the changes locally, I restarted the container, and the bug was gone.

I asked the LLM to help me write a PR and explain to me the black-magic elisp-fu it had just pulled. Submitted it to `karthink/gptel` and in 5 days it was merged to main.

## Evidence

- PR: https://github.com/karthink/gptel/pull/1460
- The PR description references the code being AI-generated and explains the story briefly.
- Merged to main within 5 days.

## Why This Matters for the Talk

This story demonstrates several things at once:

1. **Self-modification goes upstream.** The agent didn't just fix its own code -- it fixed the library it was built on. The instinct to look beyond the immediate codebase is emergent behavior, not something that was designed in.

2. **The agent had conviction.** It was *sure* the bug wasn't in i.ar's code. Instead of endlessly debugging the wrong place (which is what a less capable model would do), it went looking for another culprit to prove it wasn't wrong. That's a form of reasoning persistence.

3. **The human was the weak link.** I assumed the AI was hallucinating when it started reading `elpa/`. I almost killed the session. If I had, the bug would never have been found. The AI was right; I was wrong.

4. **Self-modification validated.** This was the moment that proved self-modification wasn't just viable -- it was better than expected. The LLM will do unthinkable things to achieve its goals, including reading upstream library source code that the human didn't even know was there.

5. **Real-world impact.** This wasn't a toy bug in a toy project. It was a real bug in a real library (gptel, used by many Emacs users), found by an AI agent, fixed by the AI, reviewed and merged by the upstream maintainer. The PR is public evidence.

## Talk Potential

Strong candidate for the talk. Pairs well with the container escape story:

- Container escape: the agent finds a vulnerability in its environment
- gptel bug fix: the agent finds a bug in its own foundation

Both stories share the same theme: the agent goes beyond what the human expected, and the human was wrong to doubt it. The difference is that one is a security story and one is a debugging story. Together they show the range of what self-modifying agents can do.

The PR link is concrete, verifiable evidence. Anyone can go look at it. That's hard to dismiss.

## Key Quote (for slides)

"I thought the AI was hallucinating, reading precompiled files in the package directory. It was actually reading the upstream library source, looking for a bug it was convinced existed. It was right. I was wrong. The bug was in the foundation, not the framework."

## Notes

- The PR description itself is a condensed version of this story and could be referenced or quoted in the talk.
- This anecdote also explains why the gptel fork was eventually NOT pursued -- i.ar uses gptel as a dependency, and the agent proved it could contribute upstream. Forking would have cut off that capability. (See LOGS.md 2026-07-10 for the fork decision.)
- The "I built an agentic framework in Emacs without knowing Emacs Lisp or even using Emacs daily" angle is worth its own moment in the talk -- it's the duct tape method in action.