# Session Summary Card Design

## Overview

When both participants complete their buddy session, show an engaging summary card instead of a rating screen.

## Design Direction

Hybrid approach combining:
- **Warmth**: Duo connection showing both participants
- **Visual punch**: Focus rings (Apple Fitness inspired)
- **Dynamic message**: Fun text based on session performance

## Layout (Top to Bottom)

### 1. Duo Connection Header
- Two circles with initials (56pt diameter)
- Connected by horizontal line
- Names below each circle
- Animation: circles fade in, line draws between them

### 2. Focus Rings + Hero Stat
- Two concentric progress rings (outer = you, inner = buddy)
- Center displays combined focus time ("70 min")
- Rings animate from 0 to completion
- Ring colors: green (you), teal (buddy)

### 3. Dynamic Message
- Fun text based on session stats
- Examples:
  - "You two are unstoppable"
  - "Laser focused!"
  - "Perfectly in sync"

### 4. Stats Breakdown
- Simple comparison: You vs Buddy
- Focus dots showing distraction-free streaks (●●●●●)
- Time and distraction count for each

### 5. Action
- Single "Done" button
- Optional "Share" for screenshot-worthy card

## Visual Treatment

- Full screen with soft green gradient background
- Card with glassmorphism (iOS blur material)
- Card scales up with spring animation on appear
- Elements fade in sequentially

## Data Required (Current Session Only)

- Your name, buddy's name
- Your duration, buddy's duration
- Your distraction count, buddy's distraction count
- Combined total focus time

## No Storage

Messages generated from current session stats only. No history tracking.
