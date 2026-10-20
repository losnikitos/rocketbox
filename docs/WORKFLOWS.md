# Workflows

A workflow ([model](/app/models/workflow.rb), edited at `/app/workflows` ([controller](/app/controllers/accounts/workflows_controller.rb))) is a graph of folder, media and step nodes joined by edges, with sticky notes beside them, edited and run on the overview's flow canvas ([workflow_controller](/app/javascript/controllers/workflow_controller.js), drawn by [flow_controller](/app/javascript/controllers/flow_controller.js): nodes at their saved `x`/`y`, no auto-layout, any sign; pan and zoom are a CSS transform on an `overflow-hidden` container, kept per page in sessionStorage; a live refresh arriving mid-drag waits for the drop).

Workflows are the media pipeline: folders, tags and the transformations their steps own. Items flowing through it are of three kinds, each living in folders of its kind ([folder.rb](/app/models/folder.rb) `kind`): media (`LibraryMedia`), prompts (`Prompt`, under the Prompts root, e.g. `prompts/shots` and `prompts/styles`, written ones landing in Prompts itself unless the step has an output folder) and reviews (`Review`, all in the one Reviews folder). A step run's inputs (`TransformationRunInput#item`) and result (`TransformationRun#result`) are polymorphic over them.

Outside the canvas:
- The index ([view](/app/views/accounts/workflows/index.html.erb)) shows each workflow's minimap ([partial](/app/views/accounts/workflows/_minimap.html.erb)): a server-rendered SVG of its nodes as boxes at their saved `x`/`y` and its edges as the canvas's curves.
- A folder's page ([view](/app/views/accounts/folders/show.html.erb)) lists the workflows that read from it (its folder nodes feeding a step) and write to it (its folder nodes a step feeds, and on Ready every step with no output folder), each linking to that node.
- A media's page ([view](/app/views/accounts/library/show.html.erb)) links a generated media to the step that made it, in its run. Its Run in workflow panel lists the start folders it fits (`Workflow.starts_for`), each playing a new run of just that media from there ([controller](/app/controllers/accounts/workflow_runs_controller.rb)).

## Prior art — don't reinvent the wheel

Workflows borrow from [n8n](https://n8n.io), [ComfyUI](https://github.com/comfyanonymous/ComfyUI), [Zapier](https://zapier.com)/[Make](https://www.make.com) and [Airflow](https://airflow.apache.org)/[Dagster](https://dagster.io). Before designing a workflow feature, check how they solve it and take their answer unless ours genuinely differs.

Where we stand:
- Every node gives a list of items of one kind, like n8n's items and ComfyUI's lists: a folder its pinned items or newest N, its subfolders' included (a media folder of its media, a prompt folder of its written prompts, Reviews of its 5-star reviews), a media itself, a step what its step runs made. Edges are typed like ComfyUI's sockets: each carries its start's kind, into a step that takes it.
- Each type declares its inputs (`Transformation::Type.inputs`): a name (a kind `:image` / `:video` / `:media` / `:prompt` / `:review`, or a role like `:first_frame`) and how many a step run takes, as a Range (`1..1`, `0..1`, `1..`, `0..`), like ComfyUI's typed inputs and `INPUT_IS_LIST`; and what it makes (`makes`). A media input of 1 (crops, edits, overlays) runs once per media it's given; the next step waits for them all, like Airflow's `.expand()`. A prompt or review input picks one per arrow into it per step run (`picks?`: a prompt at random, the newest review), except an LLM's, which takes them all; so a Shots folder and a Styles folder into Image give it one shot and one style, their bodies appended to its prompt in arrow order, each under a `# <folder name>` header (slots to place them are to come). Any other input takes all its items in each step run. An image / frame or video input skips the media that isn't one. Image takes images `1..` and prompts `0..`; Video has named ports Start (`first_frame` `1..1`), End (`last_frame` `0..1`), Refs (`reference` `0..`) and Prompt (`0..`), pinned by `WorkflowEdge#input` — Take 2 into Start makes two videos; End / Refs are muted when the model doesn't support them (e.g. Runway Gen-4.5 first-only, Grok no refs); frame roles and per-model duration/resolution/aspect come from `GenerationOptions` (OpenRouter models store synced caps in `metadata["video"]`); an LLM prompts `0..` and images `0..`; Reviews media `1..1` and a review `1..1`; reels media `1..`.
- Keeping unchanged step runs is ComfyUI's caching, per item and across runs: a step run is matched by the items it took, its picks counting while still given, so a folder's new media reruns only its own, and a new run reuses what any run already made from the same items (sharing that result, so the steps after it match too).
- Autorun's trigger is the start folder itself, like n8n's trigger node: it passes the new media on, as the run's picks, rather than just starting a run that reads the folder's pinned or newest.
- Notes are n8n's sticky notes: colored Markdown on the canvas that runs ignore. Groups that move their nodes (ComfyUI, Node-RED) and resizable notes aren't built yet.

## Graph

- Each step owns its transformation, made blank from the type added from + Add, edited in the inspector and deleted with the step.
- One end of an edge is always a step, so a folder feeding a step is an input and one a step feeds is an output.
- An edge carries its start's kind ([workflow_edge.rb](/app/models/workflow_edge.rb)): into a step, one its inputs take (`Transformation::Type.takes`: an LLM takes prompts and media, Image and Video media and prompts, Reviews media and reviews); into a folder, the folder's (an LLM writes into a prompt folder). Nothing connects into Reviews. The canvas lights up only nodes of a fitting kind (`data-gives`, `data-takes` on [_flow](/app/views/shared/_flow.html.erb)).
- A folder node gives its pinned items (`WorkflowNode#pinned_ids`), else its newest N (`WorkflowNode#take`, 1 by default) of its own and its subfolders' items (`Folder#tree_ids`), so Inbox gives what's in `inbox/interior` and `inbox/logo` too: a media folder of its media, a prompt folder of its written prompts (shared or the user's), Reviews of the user's 5-star reviews. A step then picks from what it gives (see Prior art), so a Styles folder taking 3 gives a step one of its newest 3 at random.
- A media folder node can also have tags and a media type (`WorkflowNode#media_type`: images, videos, or any by default): it holds only its media with all of them and of that type, subfolders' included. Prompt and Reviews nodes have no tags or media type.
- A step can have tags: what it makes gets them all. Its result doesn't inherit its source's tags, so a horizontal render of a `#vertical` photo gets only the step's, e.g. `#horizontal`. Steps writing one folder can tag their results apart.
- A step takes any number of edges in; an input's items come in the order its edges were connected, so media nodes give a hand-picked order (GM Visuals cuts its media in that order).
- A media node is a source that always gives that one media: it feeds steps, nothing connects into it.
- A note node is a sticky note: Markdown text (links show as plain text on the canvas) on a card in one of the folder colors, amber by default. It never connects, so runs pass it by.

## Editing

- Drag (or click) folders and transformation types in from the + Add popover over the canvas, its tabs Folders (with a search) and the types' groups: Generation, Transform, Overlay and Reels; folders from the sidebar; and a selected folder's media from the inspector.
- Drag nodes around (positions saved; Alt-drag drops a copy, a step's with its own copy of the transformation, without connections). Scroll to pan and pinch to zoom.
- Drag the empty canvas to select every node the rectangle touches; dragging any of them moves them all.
- Drag from a node's dot to another node to connect (nodes it can connect to light up). A step shows one empty port below its connections, where the next one goes.
- A selected folder's inspector sets how many of its newest items it gives (Take) and, a media folder's, of which type (Media: any, images or videos).
- Drag (or click) Note, under Notes in + Add, to drop a sticky note; its inspector edits its Markdown (saved when you click away) and color.
- Click a node to open the inspector on the right, top to bottom: its name (a step's editable in place) with a bin to remove it, its Inputs and Outputs in the selected run (see Running), its tags (a folder's "Filter by tag" (only its media with all of them), a step's "Set tags", which its results get), its Settings (a step's transformation settings, saved as you edit; a folder's Take and Media type; a note's Markdown and color), then its media (a folder's, or a media node's own). Click a connection to remove it with the bin or drag its ends to other nodes.
- Delete removes whichever is selected; clicking the empty canvas deselects.

## Running

There's no separate run mode: the canvas always shows a run ([model](/app/models/workflow_run.rb)), the one selected in the bottom panel (`?run=`), else the latest.
- A play button on a start folder or media replays the selected run, keeping each step run while it took the same inputs and its transformation wasn't saved since, so only changed steps and the steps after them rerun.
- A step with no such step run in the run reuses a complete one from any other run of the workflow that took the same inputs since its transformation was last saved: the run gets a step run sharing that result (the same media, at no cost), shown as Reused from Run N. So a new run of the same media makes nothing again.
- Run, beside + Add on the canvas and on the selected run's row, plays it from every start node at once, e.g. a reel fed by many branches.
- A step nothing feeds whose inputs all take `0..` (an LLM writing from its instruction alone) is a start node itself: its play button and Run start it with no items.
- A play button on a step's corner, shown once every step feeding it is complete in the run, starts it there, or forces a finished one to rerun afresh, never reusing (e.g. for another take, or after its type's code changed); the steps after it follow. A result another run shares stays for that run.
- A selected start folder's inspector shows its items last (media draggable onto the canvas like any folder's, prompts and reviews as text cards), each with a pin: pinned items are what it gives in every run, saved on the node until unpinned; Reset pins, or unpinning them all, goes back to its newest N. Pinned items carry a pin badge on the canvas's connections too.
- Autorun (a switch in the page header after the workflow's name, off by default): each media landing in a start folder (with all its tags, of its media type) starts a new run of its own, played from that folder with the media as its picks, as the media's owner. Landing is getting its file (uploads, Telegram, WhatsApp, a step run's result) or being moved there with one. Media with no owner, and media a workflow's own runs made, don't start that workflow. The seeded **Business card** workflow (`Workflow::BusinessCard.ensure!`) autoruns from `inbox/business-card` and `inbox/logo`: **Extract logo** → `photobank/logo`, **Update business** → User fields; when the run settles it advances WhatsApp onboarding ([WHATSAPP.md](./WHATSAPP.md)).
- A run of one media (autorun, a media page's Run in workflow) keeps it as its picks (`WorkflowRun#picks`), in place of that folder's pinned or newest, through replays and step reruns.
- A run is a draft until it's first played (from a start node or a step); then it's started. The run header shows its status: Draft, then failed, running or complete as its step runs.
- The start node's items (the run's picks, else a folder's pinned or newest N) go to the steps it feeds, and each step starts once every node feeding it gives items: a folder what it gives, a media itself, a step what all its step runs made in this run.
- Each step run is a `TransformationRun`; its result lands in the step's output folder (else Ready for what it makes: `ready` or `prompts`), a media with the step's tags. An LLM step's result is a prompt, its text written once the step run completes, so a prompt folder it writes into feeds the next steps from there. A kept step run's result gains tags added to the step since; removing one doesn't take it off.
- Each step node shows its step runs' status as a corner badge (working, complete, failed: failed if any failed, working if any is), and each connection shows everything that went along it on its middle (a step's outputs, or the media its step runs took from a folder or media; until then what the folder gives, so a folder taking 3 shows 3): one media as a thumbnail opening in a lightbox, more as a stack that opens them all in a popover around it, each opening in a lightbox from there; prompts and reviews as small text cards, stacked the same way, opening their full text in a popover.
- The bottom panel lists the runs, newest first, one row per run with its status and the media it started from and ended with; its chevron expands it to its step runs with their inputs, output, status and time. Clicking a row selects that run, highlighted. The inspector shows the selected node's inputs and outputs in the selected run, and a step's errors, above its settings; its status shows on the canvas.
- New run in the panel adds a blank run (Run N), and a run with no step still running can be deleted from its row's admin menu (its media stay in the library).
- Switching runs keeps the selected node or connection.

## Reading a workflow (agents)

Given a workflow URL, read its Markdown first: the same path plus `.md`, keeping `node` and `run` (`account` doesn't matter). So `https://dev.rocketbox.plus/app/workflows/interior?account=2&node=16&run=10` reads as:

```bash
TOKEN=$(bin/rails runner 'print Rails.application.credentials.agent_token')
curl -s -H "Authorization: Bearer $TOKEN" "https://dev.rocketbox.plus/app/workflows/interior.md?node=16&run=10"
```

The token (`agent_token` in Rails credentials, the same in production) opens only this page, nothing else. Use `http://localhost:3003` when the tunnel is down. The page ([view](/app/views/accounts/workflows/show.md.erb)) holds, top to bottom:
- **Header**: the canvas URL, autorun, start nodes, the selected node, and a short how-to-read note.
- **Graph**: a Mermaid flowchart. Node ids are `n<node id>`, the same ids used everywhere else on the page. Folders are slanted, steps are boxes with their options and tags, and media nodes are rounded.
- **Nodes**: one section per node. A step's section has its type and kind, the kinds it takes and makes, its options (as shown and raw), the tags it sets, what feeds it and where its results land, its layer and layer steps, and its prompt (an LLM's instruction) in full. A folder's section has its kind and what it gives: its pins or newest N, and the tags and media type it filters on (a media folder). Notes come last, quoted verbatim, because they often say why the workflow exists.
- **Runs**: the newest 20 runs. The selected run (`?run=`, else the latest) gets a section of its own: its picks, what it started from and ended with, and each step run's status, duration, cost, input and output items (media with folder, tags, media page and file links; prompts and reviews with their text), options, and its prompt as sent when that differs from the step's.

It's read-only: change a workflow in code or on the canvas. Opening it never creates a run, unlike the canvas.

## Vocabulary

- **Workflow** — a graph of nodes and edges (the definition).
- **Node** — a folder, media, step or note on the canvas. A **step** is a node owning its transformation; a **note** is a sticky note that never connects.
- **Edge** — a connection between two nodes, one end always a step ("connection" in the UI).
- **Start node** — a folder or media that feeds steps and that nothing feeds, or a step nothing feeds that needs no input; play starts a run from it.
- **Autorun** (`Workflow#autorun`) — a workflow setting: media landing in a start folder starts a run with it (`Workflow.autorun!`).
- **Run** (`WorkflowRun`) — one execution of a workflow. A **draft** run hasn't been played yet.
- **Pin** (`WorkflowNode#pinned_ids`) — a start folder's items (media, prompts or reviews) it gives in every run in place of its newest N, until Reset pins.
- **Item** — what flows along edges: a media, prompt or review (`item_kind`).
- **Input** — a named port a step's type takes and how many per step run (`Transformation::Type.inputs`, e.g. `{ image: 1.., prompt: 0.. }` or Video's `{ first_frame: 1..1, last_frame: 0..1, reference: 0.., prompt: 0.. }`). A prompt or review input (but an LLM's) is a **pick**: one chosen per arrow into it per step run. An edge into a step with named ports stores which one in `WorkflowEdge#input`.
- **Step run** (`TransformationRun` in a run, `WorkflowRun#step_runs`) — one execution of a step on one batch (one media for a media input of 1, else all its inputs' items) plus its picks; its result lands in the step's output folder. A reused one (`reused_from`) shares another run's result.
