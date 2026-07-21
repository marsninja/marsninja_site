---
title: What "AI-Native" Should Actually Mean
date: 2026-06-28
tags: ai, languages
summary: Calling an SDK is not a programming model. An essay on moving LLMs from library to language feature — and what that buys you.
---

Every language is now "AI-native" the way every cereal is now "protein-packed."
Usually it means: we shipped an HTTP client for a model API. That's a library,
not a programming model.

## The library ceiling

When a model call is a library call, the seams show everywhere:

```python
resp = client.chat.completions.create(
    model="...",
    messages=[{"role": "user", "content": prompt}],
)
data = json.loads(resp.choices[0].message.content)  # pray
```

You hand-build the prompt, hand-parse the output, hand-check the types, and
hand-wire the retries. The type system — the thing languages are *for* —
watches from the sidelines.

## Semantics, not strings

The alternative is to let the signature carry the meaning. In Jac's `byllm`,
a function can simply *be* a model call:

```jac
import from byllm { Model }

glob llm = Model(model_name="gpt-5.2");

"""Extract the people mentioned, with their roles."""
def extract_people(text: str) -> list[Person] by llm();
```

No prompt template, no JSON parsing, no schema drift. The docstring is the
intent; the parameter types and the return type are the contract; the runtime
compiles all of it into whatever the model needs and validates what comes
back. Change `list[Person]` to `list[Organization]` and the "prompt" updates
itself — because the prompt *is* the signature.

## What this buys you

- **Type-checked model boundaries.** A hallucinated field fails validation at
  the boundary instead of three functions later.
- **Swappable models.** The call site names no vendor; benchmarking two models
  is a one-line change.
- **Reviewable diffs.** A code review sees a signature change, not a 40-line
  prompt-string diff hiding a behavior change.

## The honest caveats

Meaning-typed functions are not magic. Latency is real, costs are real, and a
function that's *sometimes wrong* is a new kind of dependency your error
handling must respect. The point isn't that the language hides the model —
it's that the language gives the model the same first-class treatment it gives
the filesystem or the network: typed, composable, and boring.

Boring is the goal. The exciting phase of a technology ends exactly when it
becomes a language feature.
