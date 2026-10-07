# Salapify 3 - Google AI Studio Environment

This folder contains architecture notes, agent protocols, and product roadmap tracking for **Salapify 3** built and maintained within **Google AI Studio**.

---

## Active Environment Configuration

- **Branch**: `google-aistudio-build`
- **Upstream Repository**: `https://github.com/icedamericanodev/Salapify.git`
- **Frontend Stack**: Vite + React 18 + TypeScript + Tailwind CSS v4
- **Design Tokens**: Salapify 3 Hapon (Light) & Gabi (Dark)
- **Port Rule**: Ingress routes exclusively through port 3000

---

## Design System Summary

| Token | Hapon (Light) | Gabi (Dark) | Role |
|---|---|---|---|
| Canvas Background | `#FFEEDF` (Apricot Peach) | `#14100D` (Warm Black) | Full application background |
| Card Surface | `#FFFFFF` (Clean White) | `#27201A` (Deep Warm Charcoal) | Primary cards & surfaces |
| Text Primary | `#15120F` (Dark Ink) | `#F6EFE8` (Warm White) | Headings, amounts, labels |
| Text Secondary | `#6B6156` (Warm Gray) | `#AC9E92` (Muted Warm Gray) | Captions, dates, subtitles |
| Borders & Dividers | `#F3DFCD` (Light Border) | `#383029` (Dark Border) | Thin card outlines & dividing lines |
| Primary Accent | `#B03C09` (Terracotta Amber) | `#FF9A52` (Peach Ember) | Log pill, key indicators, you-owe debt |
| Income / Green | `#16643F` (Deep Emerald) | `#5FCB8E` (Vibrant Mint) | Income, owed-to-you debt, goals reached |

---

## Architecture & Data Invariants

1. **100% Offline-First**: All data is persisted in browser local storage (`salapify_*_v3`). No external tracking, no backend database dependencies.
2. **Transfer Invariant**: A transfer reallocates money between accounts without altering income or expense totals.
3. **No Em or En Dashes**: Adheres to the house rule of using standard hyphens (`--` or `-`) in code, comments, and UI.
4. **Philippine Localization**: Monetary amounts are rendered in PHP with `₱` and comma separators. The default pay cycle follows the standard 15th and 30th bimonthly cutoff.
