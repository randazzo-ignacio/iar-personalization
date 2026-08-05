# Anecdote: The Origin -- Anthropic, the Export Ban, and "How Hard Could It Be?"

## The Story

On June 11, Anthropic released their flagship Claude model (Claude Opus 4 / "fable 5"). Nacho tried it and was genuinely impressed by its performance -- enough to get enthusiastic about AI again after some time away, seeing how far the technology had come.

The very next day, the US issued an export ban on that model. Everyone outside the US lost access.

Nacho's reaction was not to find a workaround, not to wait for policy changes, and not to switch to a different cloud model. The reaction was annoyance followed by a question:

> "How hard could it be to build this myself?"

He jumped straight into Gemini to ask it for help building the foundations of what is now i.ar.

## Why This Matters for the Talk

1. **The origin is a geopolitical event.** The export ban is what triggered the entire project. This is not a "I wanted to build a cool tool" story -- it's a "someone took away my access and I decided to build my own" story. That's more compelling and more relevant to a Latin American audience, many of whom have experienced similar technology access restrictions.

2. **Local-first is not a design preference -- it's a response to exclusion.** The philosophy of "no cloud, no telemetry, no external API calls" isn't just about privacy. It's about sovereignty. When your access to a tool can be revoked by a foreign government's policy decision, depending on that tool is a strategic vulnerability. i.ar exists because that vulnerability was exposed.

3. **The timeline starts here.** June 11: tried the model. June 12: export ban. Shortly after: started building. The CTF was day 9-10. The entire project, from "how hard could it be" to "20/22 flags at a CTF," happened in roughly two weeks.

4. **The irony.** The export ban was supposed to restrict access to advanced AI. Instead, it motivated someone to build a local alternative that is now open source and available to everyone -- including the people the ban was trying to restrict. The ban created the thing it was trying to prevent.

## Talk Potential

This is the opening of the talk. Before the container escape, before the CTF, before the thesis -- this is why any of it exists. "I tried a model, it was great, it got banned, and I decided to build my own. Here's what happened."

The export ban angle also connects directly to the thesis: if a solo developer in Argentina built this in response to an export ban, what are people in other restricted regions building? The threat angle isn't just about malicious actors -- it's about the democratization of AI capability that export controls can't actually prevent.

## Key Quote (for slides)

"I tried Anthropic's flagship model. It was impressive. The next day, the US banned it. So I asked: how hard could it be to build this myself? Ten days later, the AI I built was solving CTFs I couldn't solve myself."