# Workflows

A workflow ([model](/app/models/workflow.rb), edited at `/app/workflows` ([controller](/app/controllers/accounts/workflows_controller.rb))) is a graph of folder, media and step nodes joined by edges, edited and run on the overview's flow canvas ([workflow_controller](/app/javascript/controllers/workflow_controller.js), laid out by [flow_controller](/app/javascript/controllers/flow_controller.js)).

Workflows are our new approach to building the media pipeline. For now they run in parallel with recipes, sharing folders, tags and transformations; recipes may be retired later, so build new pipeline features on workflows.

## Prior art — don't reinvent the wheel

Workflows borrow from [n8n](https://n8n.io), [ComfyUI](https://github.com/comfyanonymous/ComfyUI), [Zapier](https://zapier.com)/[Make](https://www.make.com) and [Airflow](https://airflow.apache.org)/[Dagster](https://dagster.io). Before designing a workflow feature, check how they solve it and take their answer unless ours genuinely differs.

Where we stand:
- A run carries one media per edge, like Zapier/Make (one trigger item per run), not item arrays like n8n or image batches like ComfyUI. A step with several incoming edges takes one media from each.
- Reruns that keep unchanged steps are ComfyUI's caching.

## Graph

- Each step owns its transformation (never a recipe's), made blank from the type dropped from the palette and deleted with the step.
- One end of an edge is always a step, so a folder feeding a step is an input and one a step feeds is an output.
- A folder node can hold only its media with a tag.
- A media node is a source that always gives that one media: it feeds steps, nothing connects into it.

## Editing

- Drag folders and transformation types in from the bottom palette (each tab has its own search), and a selected folder's media from the inspector.
- Drag nodes around (positions saved; Alt-drag drops a copy, a step's with its own copy of the transformation, without connections) or the empty canvas to pan.
- Drag from a node's dot to another node to connect (nodes it can connect to light up).
- Click a node to open the inspector on the right (remove, and a step's transformation settings), or a connection to remove it or drag its ends to other nodes.
- Delete removes whichever is selected; clicking the empty canvas deselects.

## Running

Run mode (`?run=`, [model](/app/models/workflow_run.rb)):
- A play button on a start folder or media replays the workflow's draft run, keeping each step run while it took the same inputs and its transformation wasn't saved since, so only changed steps and the steps after them rerun.
- A play button on a step's corner, shown once every step feeding it is complete in the run, starts it there, or forces a finished one to rerun (e.g. after its type's code changed); the steps after it follow.
- The start node's media (a folder's newest) goes to the steps it feeds, and each step starts once every node feeding it gives media: a folder its newest media, a media itself, a step what it made in this run.
- Each step run is a `TransformationRun`; its result lands in the step's output folder (Ready if none).
- Each step node shows its step run's status as a corner badge (working, complete, failed), and its output as a thumbnail on the middle of each connection out of it, opening in a lightbox on click.
- The bottom panel lists the step runs with their inputs, output, status and time; the inspector shows the selected node's inputs and outputs in the selected run (a step's also its status and how long it took) instead of its edit controls.
- One draft run per workflow for now; the run pills switch between runs.

## Vocabulary

- **Workflow** — a graph of nodes and edges (the definition).
- **Node** — a folder, media or step on the canvas. A **step** is a node owning its transformation.
- **Edge** — a connection between two nodes, one end always a step ("connection" in the UI).
- **Start folder** — a folder or media that feeds steps and that nothing feeds; play starts a run from it.
- **Run** (`WorkflowRun`) — one execution of a workflow.
- **Step run** (`TransformationRun` in a run, `WorkflowRun#step_runs`) — one execution of a step; its result lands in the step's output folder.
