+++
date = 2023-10-22
draft = false
tags = ["academia", "productivity"]
title = "Obsidian for research"
summary = """
A one-month impression.
"""
math = false
diagram = false
# [banner]
# image = "/img/posts/grenoble/grenoble.JPG"
+++

I have been using [Obsidian](https://obsidian.md) for about a month now and have been truly impressed with the application.
After some experimentations back and forth, the hype, the control and the stationary regime, I wanted to gather some notes on my usage as a researcher in applied maths / computer science.

I tried multiple notetaking / productivity applications before for research, including Trello, Evernote, Google Keep, and plain notes scattered around (the latter being my previous default solution, with github issues and TODOs in latex papers directly).

# File organization

Unlike some people, I tend to like folders (at a moderate depth) and not solely rely on search.
My vault has roughly the following struture:

```
├── _assets
│  └── templates
│     ├── paper_review.md
│     ├── research_note.md
│     ├── t_weekly.md
│     └── talk_abstract.md
├── abstracts
│  └── Summer_school_Einstein_Opt_ML.md
├── paper_reviews
│  └── warmstart_conic.md
├── preamble.sty
├── random
│  └── Spivak_notation.md
├── reading_notes
│  ├── Concepts
│  │  ├── Benders.md
│  │  └── lift_n_project.md
│  ├── Papers
│  │  ├── mirror_descent_frankwolfe.md
│  │  └── Rens_heuristc.md
│  └── Projects
│     ├── Strong_branching.md
│     └── V_polyhedral_cuts.md
└── weekly
   └── 2023-W41.md

```

Let's walk through the main folders:
- `_assets` contains the images attached to notes, PDFs, and note templates.
- `abstracts` contains my talk abstracts (I used to have them written as a one-off thing and have to scavenge my emails to gather them afterwards)
- `paper_reviews` contains the peer reviews I wrote
- `preamble.sty` I'll mention in plugins
- `random` for notes that have no other place, out of topic for instance
- `reading_notes` is the core of my Obsidian usage, with notes related to research including:
    - `Concepts` for general optimization concepts for which I want an overview note: what is Benders decomposition, etc. I also use these to group several papers on the topic while keeping a unified notation
    - `Papers` are a note on a single paper
    - `Projects` are running notes for ongoing research projects, including notes from meetings, diagrams, todos
- `weekly` for weekly running notes.

# Plugins

## Those I use

I kept it pretty simple so far. I am using the [reference map](https://github.com/anoopkcn/obsidian-reference-map) to access and reference papers quickly in notes.

In useful things for mathematics: I use Quick LaTeX for Obsidian and Extended MathJax with a bunch of commands in the `preamble.sty` file and shortcuts.
Commands I include are also the same I would use in a lot of papers to be able to copy content from one to the other.

Finally, I am using the git plugin to manage my vault as a simple github repository.

## Those I dropped

In plugins I ended up removing: the **calendar** can be useful for some poeple but it ends up being redundant with my actual calendar app, and redundancy either creates friction, duplication, or losses.

I also dropped the **daily notes**, I don't find research to work at the scale of a day, and switched to weekly notes instead.
In these, I add things to do for the current week, random small thoughts that don't deserve their full note yet, and things I am doing to be able to look back later.

# Note-taking is a means

As a final note, I would say that I spent some time setting all this up, but not an indecent amount. For anyone setting up any productivity system or app, some things should stick:
1. If you spend more time optimizing your productivity app than using it, you are probably doing it wrong
2. The benefits of using these apps only kicks in with consistency. We got very used to immediate rewards for anything we do, and any app who offers this is probably hacking your brain into feeling satisfied
3. Some "gurus" for these productivity apps tend to show you how to do *everything* in there, calendar, slides for presentations, your grocery list. Explore things that can work out, but apps are tools, and tools serve a purpose, they are not a lifestyle.

Point 1 is especially vicious, it is linked to a fake productivity feeling, we all know someone who spent too much time in research organizing their literature review, their Zotero, their bullet journal system or their note-taking system.
Taking notes should remain a fairly minor activity, one that we perform without thinking about it and that is there to support the actual work: developing new methods, designing and implementing the algorithms, preparing and running experiments, writing that paper that has been taking dust for months.

# Still to improve

In the things that I still haven't mastered: making internal links useful. Sure I can link notes to each other.
What I don't see yet is the usefulness of it in my research notes, probably because the number of notes where the benefit kicks in is not there yet.  

I also haven't managed to synchronize with the git repo system with my phone, work in progress. I also rarely needed so far to access or edit my notes on mobile so far.

-----
