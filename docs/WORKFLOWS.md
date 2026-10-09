# Workflows

A workflow ([model](/app/models/workflow.rb), edited at `/app/workflows` ([controller](/app/controllers/accounts/workflows_controller.rb))) is a graph of folder, media and step nodes joined by edges, with sticky notes beside them, edited and run on the overview's flow canvas ([workflow_controller](/app/javascript/controllers/workflow_controller.js), laid out by [flow_controller](/app/javascript/controllers/flow_controller.js)).

Workflows are the media pipeline: folders, tags and the transformations their steps own.

Outside the canvas:
- A folder's page ([view](/app/views/accounts/folders/show.html.erb)) lists the workflows that read from it (its folder nodes feeding a step) and write to it (its folder nodes a step feeds, and on Ready every step with no output folder), each linking to that node.
- A media's page ([view](/app/views/accounts/library/show.html.erb)) links a generated media to the step that made it, in its run. Its Run in workflow panel lists the start folders it fits (`Workflow.starts_for`), each playing a new run of just that media from there ([controller](/app/controllers/accounts/workflow_runs_controller.rb)).

## Prior art — don't reinvent the wheel

Workflows borrow from [n8n](https://n8n.io), [ComfyUI](https://github.com/comfyanonymous/ComfyUI), [Zapier](https://zapier.com)/[Make](https://www.make.com) and [Airflow](https://airflow.apache.org)/[Dagster](https://dagster.io). Before designing a workflow feature, check how they solve it and take their answer unless ours genuinely differs.

Where we stand:
- Every node gives a list of media, like n8n's items and ComfyUI's lists: a folder its pinned media or newest N, a media itself, a step what its step runs made.
- A reel step takes its whole inputs in one step run (ComfyUI's `INPUT_IS_LIST`); any other step runs once per item, its shorter inputs repeating their last media (ComfyUI's rule), so a product list with one style media gives one step run per product. The next step waits for them all, like Airflow's `.expand()`.
- A reel type can name its inputs (`Transformation::Type.slots`, e.g. GM Visuals' exterior, interior, features, customers), like ComfyUI's sockets and Dagster's `ins`: its media reach the run slot by slot in that order.
- Keeping unchanged step runs is ComfyUI's caching, per item and across runs: a step run is matched by the media it took, so a folder's new media reruns only its own, and a new run reuses what any run already made from the same media (sharing that result, so the steps after it match too).
- Autorun's trigger is the start folder itself, like n8n's trigger node: it passes the new media on, as the run's picks, rather than just starting a run that reads the folder's pinned or newest.
- Notes are n8n's sticky notes: colored Markdown on the canvas that runs ignore. Groups that move their nodes (ComfyUI, Node-RED) and resizable notes aren't built yet.

## Graph

- Each step owns its transformation, made blank from the type added from + Add, edited in the inspector and deleted with the step.
- One end of an edge is always a step, so a folder feeding a step is an input and one a step feeds is an output.
- A folder node can have tags and a media type (`WorkflowNode#media_type`: images, videos, or any by default): it holds only its media with all of them and of that type, and gives its pinned media (`WorkflowNode#pinned_media_ids`), else its newest N (`WorkflowNode#take`, 1 by default).
- A step can have tags: what it makes gets them all. Its result doesn't inherit its source's tags, so a horizontal render of a `#vertical` photo gets only the step's, e.g. `#horizontal`. Steps writing one folder can tag their results apart.
- An edge into a step with slots goes into one of them (`slot`); edges in one slot keep the order they were connected in, so media nodes there give a hand-picked order.
- A media node is a source that always gives that one media: it feeds steps, nothing connects into it.
- A note node is a sticky note: Markdown text (links show as plain text on the canvas) on a card in one of the folder colors, amber by default. It never connects, so runs pass it by.

## Editing

- Drag (or click) folders and transformation types in from the + Add popover over the canvas, its tabs Folders (with a search) and the types' groups: Generation, Transform, Overlay and Reels; and a selected folder's media from the inspector.
- Drag nodes around (positions saved; Alt-drag drops a copy, a step's with its own copy of the transformation, without connections). Scroll to pan and pinch to zoom.
- Drag the empty canvas to select every node the rectangle touches; dragging any of them moves them all.
- Drag from a node's dot to another node to connect (nodes it can connect to light up); into a step with slots, drop on a labelled port, or anywhere on it for the first free one.
- A selected folder's inspector sets how many of its newest media it gives (Take) and of which type (Media: any, images or videos).
- Drag (or click) Note, under Notes in + Add, to drop a sticky note; its inspector edits its Markdown (saved when you click away) and color.
- Click a node to open the inspector on the right, top to bottom: its name (a step's editable in place) with a bin to remove it, its Inputs and Outputs in the selected run (see Running), its tags (a folder's "Filter by tag" (only its media with all of them), a step's "Set tags", which its results get), its Settings (a step's transformation settings, saved as you edit; a folder's Take and Media type; a note's Markdown and color), then its media (a folder's, or a media node's own). Click a connection to remove it with the bin or drag its ends to other nodes.
- Delete removes whichever is selected; clicking the empty canvas deselects.

## Running

There's no separate run mode: the canvas always shows a run ([model](/app/models/workflow_run.rb)), the one selected in the bottom panel (`?run=`), else the latest.
- A play button on a start folder or media replays the selected run, keeping each step run while it took the same inputs and its transformation wasn't saved since, so only changed steps and the steps after them rerun.
- A step with no such step run in the run reuses a complete one from any other run of the workflow that took the same inputs since its transformation was last saved: the run gets a step run sharing that result (the same media, at no cost), shown as Reused from Run N. So a new run of the same media makes nothing again.
- Run, beside + Add on the canvas and on the selected run's row, plays it from every start folder and media at once, e.g. a reel fed by many branches.
- A play button on a step's corner, shown once every step feeding it is complete in the run, starts it there, or forces a finished one to rerun afresh, never reusing (e.g. for another take, or after its type's code changed); the steps after it follow. A result another run shares stays for that run.
- A selected start folder's inspector shows its media last (draggable onto the canvas like any folder's), each with a pin: pinned media are what it gives in every run, saved on the node until unpinned; Reset pins, or unpinning them all, goes back to its newest N.
- Autorun (a switch in the page header after the workflow's name, off by default): each media landing in a start folder (with all its tags, of its media type) starts a new run of its own, played from that folder with the media as its picks, as the media's owner. Landing is getting its file (uploads, Telegram, WhatsApp, a step run's result) or being moved there with one. Media with no owner, and media a workflow's own runs made, don't start that workflow.
- A run of one media (autorun, a media page's Run in workflow) keeps it as its picks (`WorkflowRun#picks`), in place of that folder's pinned or newest, through replays and step reruns.
- A run is a draft until it's first played (from a start node or a step); then it's started. The run header shows its status: Draft, then failed, running or complete as its step runs.
- The start node's media (the run's picks, else a folder's pinned or newest N) go to the steps it feeds, and each step starts once every node feeding it gives media: a folder its pinned or newest N, a media itself, a step what all its step runs made in this run.
- Each step run is a `TransformationRun`; its result lands in the step's output folder (Ready if none), with the step's tags. A kept step run's result gains tags added to the step since; removing one doesn't take it off.
- Each step node shows its step runs' status as a corner badge (working, complete, failed: failed if any failed, working if any is), and each connection shows what last went along it as a thumbnail on its middle (a step's output, or the media a step took from a folder or media), opening in a lightbox on click.
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
- **Nodes**: one section per node. A step's section has its type and kind, its options (as shown and raw), the tags it sets, what feeds it and where its results land, its slots, shot group, layer and layer steps, and its prompt and style text in full. A folder's section has Take N and the tags and media type it filters on. Notes come last, quoted verbatim, because they often say why the workflow exists.
- **Runs**: the newest 20 runs. The selected run (`?run=`, else the latest) gets a section of its own: its picks, what it started from and ended with, and each step run's status, duration, cost, input and output media (with folder, tags, media page and file links), options, shot, and its prompt as sent when that differs from the step's.

It's read-only: change a workflow in code or on the canvas. Opening it never creates a run, unlike the canvas.

## Vocabulary

- **Workflow** — a graph of nodes and edges (the definition).
- **Node** — a folder, media, step or note on the canvas. A **step** is a node owning its transformation; a **note** is a sticky note that never connects.
- **Edge** — a connection between two nodes, one end always a step ("connection" in the UI).
- **Start folder** — a folder or media that feeds steps and that nothing feeds; play starts a run from it.
- **Autorun** (`Workflow#autorun`) — a workflow setting: media landing in a start folder starts a run with it (`Workflow.autorun!`).
- **Run** (`WorkflowRun`) — one execution of a workflow. A **draft** run hasn't been played yet.
- **Pin** (`WorkflowNode#pinned_media_ids`) — a start folder's media it gives in every run in place of its newest N, until Reset pins.
- **Step run** (`TransformationRun` in a run, `WorkflowRun#step_runs`) — one execution of a step on one batch of media (one item, or a reel's whole inputs); its result lands in the step's output folder. A reused one (`reused_from`) shares another run's result.
- **Slot** — a named input of a step whose type declares them (`Transformation::Type.slots`); an edge into it carries its `slot`.
