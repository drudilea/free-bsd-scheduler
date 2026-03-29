# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

University thesis repository about FreeBSD kernel scheduler enhancements using Petri nets. Contains:
- **LaTeX thesis document** (`thesis_document/current/`) — the main deliverable
- **FreeBSD kernel source modifications** (`project_files/migration_files/`) — scheduler changes across FreeBSD versions (11.0.0 through 13.0.0)
- **Kernel modules** (`project_files/modules/`) — `pin_threads`, `toggle_active_cpu_km`
- **Test programs** (`project_files/test_files/`) — C programs for benchmarking (fork, OpenMP, single-thread)
- **Petri net model** (`pipe/ResourceNet4CPUs.xml`) — PIPE-format net used in the research
- **Setup guides** (`utils/`) — VM setup, kernel compilation, remote debugging, SSH config

## Building the Thesis Document

```bash
cd thesis_document/current
latexmk -pdf main.tex        # full build
latexmk -pdf -pvc main.tex   # continuous build with preview
latexmk -c                   # clean auxiliary files
```

Requires MacTeX or BasicTeX. Missing packages: `sudo tlmgr install <package>`.

## Thesis Structure

`main.tex` is the root file (book class, Spanish). Chapter order:
1. `chapter01.tex` — Introduction/objectives
2. `chapter02.tex` — Theoretical framework
3. `chapter03.tex` — Implementation
4. `chapter04.tex` — Results/analysis
5. `conclusion.tex`, `abstract.tex`, `appendix.tex`, `bibliografia.tex`

Images referenced from `thesis_document/current/images/` (relative paths in `\includegraphics`).

## Language

The thesis is written in **Spanish**. All LaTeX content, comments, and text should be in Spanish.

## Kernel Modules (FreeBSD)

Built with FreeBSD kernel module Makefiles (`KMOD`-based). Each module has its own `Makefile` under `project_files/modules/` or `project_files/other/`.
