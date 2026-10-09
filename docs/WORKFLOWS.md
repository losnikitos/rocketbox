# Workflows

A workflow ([model](/app/models/workflow.rb), edited at `/app/workflows` ([controller](/app/controllers/accounts/workflows_controller.rb))) is a graph of folder, media and step nodes joined by edges, with sticky notes beside them, edited and run on the overview's flow canvas ([workflow_controller](/app/javascript/controllers/workflow_controller.js), laid out by [flow_controller](/app/javascript/controllers/flow_controller.js)).

Workflows are the media pipeline: folders, tags and the transformations their steps own.

Outside the canvas:
- A folder's page ([view](/app/views/accounts/folders/show.html.erb)) lists the workflows that read from it (its folder nodes feeding a step) and write to it (its folder nodes a step feeds, and on Ready every step with no output folder), each linking to that node.
- A media's page ([view](/app/views/accounts/library/show.html.erb)) links a generated media to the step that made it, in its run. Its Run in workflow panel lists the start folders it fits (`Workflow.starts_for`), each playing a new run of just that media from there ([controller](/app/controllers/accounts/workflow_runs_controller.rb)).

## Prior art — don't reinvent the wheel

Workflows borrow from [n8n](https://n8n.io), [ComfyUI](https://github.com/comfyanonymous/ComfyUI), [Zapier](https://zapier.com)/[Make](https://www.make.com) and [Airflow](https://airflow.apache.org)/[Dagster](https://dagster.io). Before designing a workflow feature, check how they solve it and take their answer unless ours genuinely differs.

Where we stand:
- Every node gives a list of media, like n8n's items and ComfyUI's lists: a folder its newest N, a media itself, a step what its step runs made.
- A reel step takes its whole inputs in one step run (ComfyUI's `INPUT_IS_LIST`); any other step runs once per item, its shorter inputs repeating their last media (ComfyUI's rule), so a product list with one style media gives one step run per product. The next step waits for them all, like Airflow's `.expand()`.
- A reel type can name its inputs (`Transformation::Type.slots`, e.g. GM Visuals' exterior, interior, features, customers), like ComfyUI's sockets and Dagster's `ins`: its media reach the run slot by slot in that order.
- Reruns that keep unchanged step runs are ComfyUI's caching, per item: a step run is matched by the media it took, so a folder's new media reruns only its own.
- Autorun's trigger is the start folder itself, like n8n's trigger node: it passes the new media on, as the run's picks, rather than just starting a run that reads the folder's newest.
- Notes are n8n's sticky notes: colored Markdown on the canvas that runs ignore. Groups that move their nodes (ComfyUI, Node-RED) and resizable notes aren't built yet.

## Graph

- Each step owns its transformation, made blank from the type added from + Add, edited in the inspector and deleted with the step.
- One end of an edge is always a step, so a folder feeding a step is an input and one a step feeds is an output.
- A folder node can have tags: as an input it holds only its media with all of them, and gives its newest N (Newest, 1 by default); as an output, what lands in it gets them all.
- An edge into a step with slots goes into one of them (`slot`); edges in one slot keep the order they were connected in, so media nodes there give a hand-picked order.
- A media node is a source that always gives that one media: it feeds steps, nothing connects into it.
- A note node is a sticky note: Markdown text (links show as plain text on the canvas) on a card in one of the folder colors, amber by default. It never connects, so runs pass it by.

## Editing

- Drag (or click) folders and transformation types in from the + Add popover over the canvas, its tabs Folders (with a search) and the types' groups: Generation, Transform, Overlay and Reels; and a selected folder's media from the inspector.
- Drag nodes around (positions saved; Alt-drag drops a copy, a step's with its own copy of the transformation, without connections). Scroll to pan and pinch to zoom.
- Drag the empty canvas to select every node the rectangle touches; dragging any of them moves them all.
- Drag from a node's dot to another node to connect (nodes it can connect to light up); into a step with slots, drop on a labelled port, or anywhere on it for the first free one.
- A selected folder's inspector sets how many of its newest media it gives (Newest).
- Drag (or click) Note, under Notes in + Add, to drop a sticky note; its inspector edits its Markdown (saved when you click away) and color.
- Click a node to open the inspector on the right: first what it did in the selected run (see Running), then its settings (remove, a folder's tags — "Only media tagged" on an input, "Tag what lands here" on an output — and Newest, a step's transformation settings). Click a connection to remove it or drag its ends to other nodes.
- Delete removes whichever is selected; clicking the empty canvas deselects.

## Running

There's no separate run mode: the canvas always shows a run ([model](/app/models/workflow_run.rb)), the one selected in the bottom panel (`?run=`), else the latest.
- A play button on a start folder or media replays the selected run, keeping each step run while it took the same inputs and its transformation wasn't saved since, so only changed steps and the steps after them rerun.
- A play button on a step's corner, shown once every step feeding it is complete in the run, starts it there, or forces a finished one to rerun (e.g. after its type's code changed); the steps after it follow.
- A selected start folder's inspector shows its media (draggable onto the canvas like any folder's), those play takes checked (its newest N); checking others picks them for this run only (`WorkflowRun#picks`), and Newest N, or unchecking them all, goes back.
- Autorun (a switch in the page header after the workflow's name, off by default): each media landing in a start folder (with all its tags) starts a new run of its own, played from that folder with the media as its picks, as the media's owner. Landing is getting its file (uploads, Telegram, WhatsApp, a step run's result) or being moved there with one. Media with no owner, and media a workflow's own runs made, don't start that workflow.
- A run is a draft until it's first played (from a start node or a step); then it's started and its picks are locked, though replays and step reruns still go, taking them. The run header shows its status: Draft, then failed, running or complete as its step runs.
- The start node's media (a folder's newest N, or what's picked for the run) go to the steps it feeds, and each step starts once every node feeding it gives media: a folder its newest N, a media itself, a step what all its step runs made in this run.
- Each step run is a `TransformationRun`; its result lands in the step's output folder (Ready if none), with that folder's tags.
- Each step node shows its step runs' status as a corner badge (working, complete, failed: failed if any failed, working if any is), and each connection shows what last went along it as a thumbnail on its middle (a step's output, or the media a step took from a folder or media), opening in a lightbox on click.
- The bottom panel lists the runs, newest first, one row per run with its status and the media it started from and ended with; its chevron expands it to its step runs with their inputs, output, status and time. Clicking a row selects that run, highlighted. The inspector shows the selected node's inputs and outputs in the selected run (a step's also its status and how long it took) above its settings.
- New run in the panel adds a blank run (Run N), and a run with no step still running can be deleted from its row's admin menu (its media stay in the library).
- Switching runs keeps the selected node or connection.

## Vocabulary

- **Workflow** — a graph of nodes and edges (the definition).
- **Node** — a folder, media, step or note on the canvas. A **step** is a node owning its transformation; a **note** is a sticky note that never connects.
- **Edge** — a connection between two nodes, one end always a step ("connection" in the UI).
- **Start folder** — a folder or media that feeds steps and that nothing feeds; play starts a run from it.
- **Autorun** (`Workflow#autorun`) — a workflow setting: media landing in a start folder starts a run with it (`Workflow.autorun!`).
- **Run** (`WorkflowRun`) — one execution of a workflow. A **draft** run hasn't been played yet, so its picks can still change.
- **Step run** (`TransformationRun` in a run, `WorkflowRun#step_runs`) — one execution of a step on one batch of media (one item, or a reel's whole inputs); its result lands in the step's output folder.
- **Slot** — a named input of a step whose type declares them (`Transformation::Type.slots`); an edge into it carries its `slot`.
