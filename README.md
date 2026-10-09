# Don't Crash — Autonomous Driving Safety-Testing Platform

A simulation-based platform for testing autonomous-driving agents against
configurable scenarios, evaluating their behavior against defined safety
criteria, and reproducing and analyzing failures.

**Team:** Waymo's Legal Team
**Course:** CSE 4316 Senior Design I, The University of Texas at Arlington, Fall 2026
**Sponsor:** Dr. Alex Dillhoff · **Senior Design Professor:** Dr. Conly

## Problem

Autonomous driving systems must operate safely across a wide range of complex,
unpredictable road conditions. Manually designing and running enough tests to
surface rare or unexpected failures is slow and expensive, and can leave safety
risks undiscovered. The project addresses the need for an efficient, repeatable
way to explore hazardous driving conditions, define measurable safety
expectations, identify the conditions that cause a system to fail, and reproduce
those failures for analysis.

## Overview

The platform is built on [CARLA](https://carla.org), an open-source driving
simulator. A user configures an experiment by selecting a driving agent, a
scenario, the conditions to vary, and the safety criteria to evaluate against.
The platform runs the experiment in simulation, grades the agent's behavior, and
stores the settings, outcomes, and logs so that failures can be reproduced and
agents, versions, and testing methods can be compared. The project builds on
existing tools — CARLA, ScenarioRunner, and the surrounding research ecosystem —
rather than recreating them. Testing is conducted entirely in simulation.

## System architecture

The platform is organized into three stages (Figure 1 of the
[Project Charter](docs/Project_Charter.pdf)):

| Stage | Components | Function |
|---|---|---|
| Setup | User Interface, Test Configuration | Select the agent, scenario, conditions, safety criteria, and testing method. |
| Search loop | Test Selection → Test Execution → Failure Evaluation | Select conditions, run each test in CARLA, grade each run against the safety criteria, and feed results back into selection. |
| Results | Results Storage, Results Review, Statistical Analysis | Store settings, outcomes, and logs; review and compare runs; summarize failure rates. |

The driving simulator (CARLA) and the driving agent under test are external to
the platform. A plain-language LLM results interpreter is a possible extension.

## Technology stack

| Layer | Tool | Version |
|---|---|---|
| Simulator | CARLA (Unreal Engine 4.26) | 0.9.16 |
| Scenario definition and grading | ScenarioRunner | 0.9.16 |
| Driving-agent ML | PyTorch (CUDA) | 2.8.0 + cu128 |
| Autonomy messaging | ROS 2 Humble | RoboStack build |
| Language | Python | 3.11 |

All foundational software is open source and requires no commercial licensing.

## Repository layout

```
.
├── README.md            Project overview
├── docs/                Formal deliverables
│   ├── README.md        Deliverables index and status
│   └── Project_Charter.pdf
└── carla/               Simulation environment (self-contained)
    ├── README.md        Setup guide: Linux and Windows, NVIDIA and AMD
    ├── install.sh       One-command installer (Linux)
    ├── install.ps1      One-command installer (Windows)
    └── setup/           Helper scripts, requirements, smoke tests
```

## Getting started

Install the simulation environment with one command:
```bash
cd carla && ./install.sh                                      # Linux
```
```powershell
cd carla; powershell -ExecutionPolicy Bypass -File .\install.ps1   # Windows
```

See [`carla/README.md`](carla/README.md) for requirements, installer options,
the equivalent manual steps, PyTorch on NVIDIA and AMD GPUs, optional ROS 2, and
running CARLA and scenarios.

## Team

- Ariel Zambeck
- Ghiya El Daouk El Kadi
- Rohita Konjeti
- Bryce Burdett
- Shawn Abraham
- Ella Daley

Responsibilities are assigned per major component: sponsor communication and
project planning; simulation and driving-agent integration; failure-search and
optimization methods; the testing side (safety requirements, criteria, and
method comparison); the platform and dashboard interface; and system integration
and the test execution pipeline. The team uses Scrum, with the Scrum Master role
rotating among members.

## Milestones

| Milestone | Target |
|---|---|
| Project Charter (first draft) | September 2026 |
| System Requirements Specification | October 2026 |
| Detailed Design Specification | October 2026 |
| Architectural Design Specification | November 2026 |
| Demonstration of Visual Interface | December 2026 |
| Demonstration of basic simulation scenarios | January 2027 |
| Demonstration of Statistics Collection | February 2027 |
| Demonstration of expanded simulation scenarios | March 2027 |
| Demonstration of Failure Evaluation | April 2027 |
| CoE Innovation Day poster and Final Demonstration | April 2027 |

## Documentation

Formal deliverables are in [`docs/`](docs/); see the
[deliverables index](docs/README.md) for the complete list and status. The
`carla/` module satisfies the Installation Scripts deliverable and contributes
to the User Manual.
