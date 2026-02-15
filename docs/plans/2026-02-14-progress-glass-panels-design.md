# Progress Screen "Glass Panels" Redesign

## Goal
Replace the generic 3-stat-card grid layout with asymmetric glass panels that feel premium and unique.

## Design

### Hero Panel (full-width)
- Full-width `.ultraThinMaterial` background, 24pt corner radius
- Big focus time with shimmer gradient (teal -> cyan)
- "focused this week" subtitle
- Comparison pill (unchanged)
- Embedded sparkline at bottom: 7 dots connected by line, today's dot highlighted/larger. Replaces separate bar chart.
- Subtle 1px border (white opacity 0.15) for glass edge

### Asymmetric Stat Panels (2 rows)

**Row 1:**
- Large panel (2/3 width): Streak - flame icon, animated gradient bg (orange->red), streak number big, 7 tiny dots showing which days had sessions
- Small panel (1/3 width): Distractions - total count, "this week" label, green/orange by count

**Row 2:**
- Small panel (1/3 width): Focus score - avg number, "avg focus" label
- Large panel (2/3 width): Recharge - bolt icon, percentage, vs last week text, thin progress bar

All panels: `.ultraThinMaterial`, 20pt corners, 1px border (white opacity 0.1)

### Task Breakdown
Same donut + legend, glass container treatment

### Insights/Charts Tabs
Glass tab picker, insight items as compact rows instead of cards

## Data (unchanged)
All computed properties stay the same. Only the view layer changes.
