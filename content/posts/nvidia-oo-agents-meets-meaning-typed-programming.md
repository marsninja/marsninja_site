---
title: NVIDIA's New Agent Framework Is Jac's by llm(), Two Years Later
date: 2026-07-31
tags: jac, mtp, agents, ai, research
summary: NVIDIA's NOOA framework makes typed, LLM-completed methods the core agent abstraction. I read the paper closely: what it validates about Jac's by llm(), what it misses, and what we're adopting.
---

NVIDIA published a paper this month introducing **NOOA** (NVIDIA-labs OO Agents, [arXiv:2607.20709](https://arxiv.org/abs/2607.20709)), a Python framework built on one idea: an agent is a Python object. Methods are the actions the model can take. Fields are model-visible state. Docstrings are prompts. Type annotations are contracts. A method whose body is `...` is completed at runtime by an LLM-driven loop.

If you've worked in Jac, you'll recognize the abstraction. A typed function with no body, whose signature is the contract, whose semantics become the prompt, and whose return type is enforced with corrective retries is *Meaning-Typed Programming* (MTP), the abstraction behind Jac's `by llm()`. [We published MTP at OOPSLA 2025](https://arxiv.org/abs/2405.08965), and the Jaseci stack shipped its production lineage years earlier. NOOA cites neither, and I'll get to that. The paper deserves a careful read first, and this post gives it one: what NOOA independently validates, the two capabilities where it's ahead of our runtime, the places where it's behind the published MTP design, the machinery a language absorbs that a framework rebuilds by hand, and the four items it adds to our roadmap.

## What NOOA is

NOOA is good work, and I want that on the record before anything else. The results are real, and three of its design decisions deserve adoption well beyond this framework: validated typed termination, bounded previews over live objects, and a memory subsystem measured with a proper ablation. The framework lets you write this:

```python
class SupportAgent(Agent):
    """You are a support agent for a customer service system."""

    order_db: OrderDB  # model-visible state, passed by reference

    def is_refund_eligible(self, order: Order) -> bool:
        """Return whether an order is eligible for a refund."""
        return order.delivered and order.days_since_delivery <= 30

    @strategy(PredictStrategy())
    async def classify(self, message: str) -> TicketKind:
        """Classify the customer message into the best ticket kind."""
        ...

    @strategy(CodeActStrategy())
    async def triage(self, message: str, order: Order | None) -> Ticket:
        """Triage a customer message and create a support ticket."""
        ...
```

The `...` bodies are agentic methods. **Predict** is a single typed LLM call with validation and retry. **CodeAct** runs a loop in which the model writes Python against live objects: it can call `is_refund_eligible()`, inspect `order`, and must terminate by returning a value that validates against `Ticket`.

The evaluation carries hard numbers. A 253-line benchmark-agnostic agent reaches 82.2% on SWE-bench Verified, the best open-harness result in their comparison. The same architecture posts the top open-source score on CyberGym L1 at 86.8%. On ARC-AGI-3, the harness multiplies the raw model's score by 6.4x, and the memory subsystem alone is worth +11.8 points over the identical agent using markdown notes.

The paper claims six model-facing capabilities as the first combined on a single surface: typed I/O, pass by reference, code as action, loop engineering, object state, and model-callable harness APIs. A careful fourteen-framework survey backs the claim.

## NOOA and MTP, construct by construct

The core mechanism lines up with Jac's, item for item:

| NOOA (Python framework, 2026) | Jac (language, OOPSLA 2025 and earlier) |
|---|---|
| `...` body marks an agentic method | a bodiless `def f(x: str) -> T by llm();` |
| the docstring becomes the prompt | `sem` strings synthesized into the prompt |
| the return annotation is validated, with retries | the return type rendered as a schema, typed retry, `OutputConversionError` |
| `PredictStrategy`, a single typed call | plain `by llm()` |
| `CodeActStrategy` with methods on `self` as tools | `by llm(tools=[self.add_task, ...])` with a ReAct loop |
| typed validated termination via `return_result` | a synthesized `finish_tool(output: T)`, validated before return |
| object fields rendered into context each turn | `self` injected into the prompt with field-level semantics |
| per-method model override in the decorator | per-call `by llm(model_name=..., temperature=...)` |

For example, the Jac form of NOOA's `classify` method is two lines:

```jac
def classify(message: str) -> TicketKind by llm();
sem classify = "Classify the customer message into the best ticket kind";
```

and the Jac form of an agentic method with tools on `self` is one declaration:

```jac
def route_and_run(utterance: str) -> str by llm(
    tools=([self.add_task, self.get_current_time, self.summarize_tasks]));
```

The paper's related work is thorough on the framework side. It cites DSPy, LMQL, Outlines, Instructor, TypeChat, CodeAct, smolagents, AskIt, and ANPL. MTP doesn't appear. Jaseci doesn't appear. I checked all 49 pages: the only occurrence of the substring "jac" is an author named Jacky.

I don't read the omission as bad faith. A team surveying agent frameworks reads framework papers, and nothing routes them through OOPSLA unless they search for it. But AskIt and ANPL, narrower versions of the same design point, made the survey. So I've filed the request as [issue #68](https://github.com/NVIDIA-NeMo/labs-OO-Agents/issues/68) on their repository, and I kept it friendly: the fix is one citation in one paragraph, and it would mean a lot to the students who built MTP.

The convergence itself is the more important fact. Fifteen authors at NVIDIA arrived at a very similar abstraction from PyTorch's design sensibilities rather than from language design, and their own survey shows fourteen other frameworks drifting the same direction. The claim that hand-written prompts are glue code, and that typed program structure should absorb them, is no longer a Jac position. It's where the field is converging.

## Where NOOA is ahead of our runtime

Scored against their six-capability rubric, Jac today supports typed I/O and object state fully, supports loop engineering and pass by reference partially, and lacks two capabilities outright. Both gaps matter, and I'd rather name them myself.

**Code as action.** Jac's agentic loop is tool calling: the model emits one structured call per round trip, and the runtime executes it. NOOA's CodeAct makes writing code the action. The model composes loops, conditionals, and `asyncio.gather` fan-outs over its tools, and intermediate results stay bound to variables instead of flowing through the transcript. The token accounting makes the case: NOOA reaches 82.2% on SWE-bench using roughly 28 model calls and 1.1M tokens per task, while a comparison harness reaches 78.2% using 66 calls and 2.2M tokens. That's half the tokens and fewer calls for a higher score.

**Pass by reference with bounded previews.** When byLLM builds a prompt today, argument values are serialized in full. NOOA renders a preview instead: the concrete type, the true length, and a head/tail sample, while the full object stays live in the execution environment. A method can accept a million-row table and the agent processes all of it by writing code, while the prompt carries a fixed-size preview. The paper states the principle plainly: the amount of data an agent can process is bounded by the execution environment, not by the prompt.

**Model-callable harness APIs.** NOOA exposes structured context blocks and a typed, queryable event history to the model itself. The agent can compact its own history, query past events, and manage its working context. Our equivalents (iteration callbacks, automatic compaction) are developer-side APIs the model never sees.

## Where NOOA is behind the MTP design

The comparison runs in both directions. Measured against the published MTP design ([arXiv:2405.08965](https://arxiv.org/abs/2405.08965), OOPSLA 2025), NOOA trails in four places, and each traces to the same root: MTP is designed into the programming language, and NOOA is confined to what a Python library can reach.

**Semantic extraction is compiled, not reflected.** NOOA assembles prompts by runtime reflection over docstrings and annotations, and nothing checks that the reflected surface is current or complete. MTP's compiler builds **MT-IR**, a meaning-based intermediate representation, at compile time: it resolves the type declarations a delegation site references, including declarations defined in other modules, and carries their names, types, and `sem` strings into the runtime. A compiled semantic surface is checkable. A `sem` declaration binds to a verified declaration path, so renaming a field surfaces the dangling annotation as a compiler diagnostic instead of a silently degraded prompt. Reflection also pays its cost on every call. MT-IR pays once.

**The human channel and the machine channel are separate.** NOOA overloads the docstring: one string documents the method for maintainers and instructs the model at runtime, so editing the documentation silently changes agent behavior. Jac gives machine-facing meaning its own construct, `sem`, and documentation and specification evolve independently.

**The developer side is measured.** NOOA's evaluation asks whether models can operate the interface, and answers with 97.9%. MTP's evaluation also asks whether humans can. In its user study, developers completed LLM-integration tasks 3.2x faster with MTP and modified 45% fewer lines of code than with existing frameworks, and accuracy held with naming quality degraded by up to 50%. NOOA reports no developer-effort or robustness measurements. For a system whose thesis is developer ergonomics, that's the missing half of the evidence.

**Delegation is an operator, not a decorator API.** NOOA's agentic methods live inside classes that subclass `Agent` and activate through strategy decorators. Jac's `by` is grammar. It attaches to a function, to a method on any archetype, or to a traversal statement, and its target is a configured value rather than a framework class. New execution strategies extend the operator's target set instead of forking the framework, and the same operator delegates control flow as readily as function bodies, as the next section shows.

This is the payoff of designing the abstraction directly into the programming language rather than layering it on top. A framework's ceiling is its host language's reflection API. A language's ceiling is its compiler. When delegation is a language construct, the type checker flows through delegated calls, the intermediate representation carries semantics across module boundaries, the formatter, checker, and language server treat the delegation site as first-class, and the runtime receives a specification the compiler has already verified. I make this argument at book length, from language-level LLM integration through the object-spatial semantics below, in *A Synechic and Topokinetic Programming Language: Continuity, Motion, and the Design of Jac* ([Zenodo, DOI 10.5281/zenodo.21577609](https://zenodo.org/records/21577609)).

## What the language absorbs

The same principle extends past the delegation site, and here the framework meets the limits of its host at every point.

**Object state persists.** NOOA's object state is fields on a Python instance, and it dies with the process. Durable state required the authors to build a full memory subsystem. In Jac, state hangs from `root` and persists because the topology persists, per user, with no database in the program.

**Appendix C is the section I keep returning to, because I recognize the design.** It describes a typed memory graph with activation spreading over its edges. It describes memories holding `kind:key` references resolved against live agent state at recall time, because copies go stale. It describes consolidation as a background pass that rewires what earlier writes laid down. This is Object-Spatial Programming, rebuilt from the outside by a team that hasn't read it: memory as typed topology, recall as traversal, salience as edge attributes, forgetting as edge deletion, consolidation as a background walker. They needed a SQLite store, an ACT-R retrieval pipeline, and an appendix. A walker over a persistent graph needs a page of ordinary code, and their own ablation prices the difference at +11.8 points.

Jac also expresses one capability NOOA can't. The statement `visit [-->] by llm(intent=...)` hands the model live handles to graph nodes and constrains its selection to a generated enum of valid destinations. This is pass by reference over a persistent topology. A flat object model has no equivalent.

## The training-distribution objection

NOOA's first design principle is the strongest published argument against building a language at all: reuse Python abstractions, because models are trained on Python. Their capability suite shows ten models operating the NOOA interface at 97.9% across 4,400 test records.

The 97.9% carries its own counterargument, and it's the detail I'd flag for anyone citing this paper against language-level design. The NOOA interface appears in no training corpus. It shipped this year. Models operate it near-perfectly because it's well structured, not because it's familiar, and that is the bet Jac makes. It's also why `jac mcp` exists: the compiler gives a stochastic author a deterministic oracle (parse, type-check, explain, repair), and the oracle substitutes for familiarity.

The remaining difference is where the glue goes. Every capability NOOA bolts on (the memory graph, the persistence layer, the live-reference discipline, per-agent scoping) is glue that a language can absorb into semantics. The paper's own description of the agent class, "simultaneously source code, prompt surface, type contract, tool interface, and state boundary," is an argument for one continuous typed medium, carried as far as a Python library can carry it. The library stops at the process boundary, at persistence, at multi-user scale, and at a type system that can't see the prompt.

## What we're adopting

Four NOOA capabilities map directly onto our roadmap, and I'm glad to take them. The `by` operator was designed as a generic delegation construct, so none of them require new syntax.

1. **A code-action execution mode for `by llm(tools=...)`.** The model writes code against live scope instead of emitting one tool call per turn. Jac holds an advantage NOOA can't reach here: generated Jac can be validated by the actual compiler inside the loop before it executes.
2. **Bounded argument previews in prompt synthesis.** Shaped previews for large values, with the full object reachable through tools. This is the cheapest gap to close, and NOOA's token numbers put a value on it.
3. **Model-callable context and event APIs in the ReAct loop.** The runtime already tracks iteration state and compaction. We plan to expose them as tools the model can query and manage.
4. **An OSP-native memory package.** Episodes and concepts as nodes, salience as edge attributes, consolidation as a background walker. NOOA's design decisions transfer directly: verbal importance scales, spontaneous recall that doesn't reinforce activation, and references in place of copies. The reference discipline costs nothing in Jac, because graph references are already live.

So here's where I land. NOOA is the strongest independent validation the meaning-typed layer of our stack has received, and its own ablations measure the cost of rebuilding the object-spatial layer as middleware. We're adopting the four capabilities where they're ahead of us. I've asked the team for the citation, and I'd enjoy comparing notes beyond it. I'll report on each roadmap item as it lands.
