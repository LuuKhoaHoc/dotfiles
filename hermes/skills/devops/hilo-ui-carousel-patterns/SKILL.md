---
name: hilo-ui-carousel-patterns
description: "Use when editing @hilo/ui Carousel or adding wheel scroll."
---

# @hilo/ui Carousel Patterns

Use when modifying `packages/ui/src/components/ui/Carousel.tsx` or building/editing carousels (tab strips, card carousels) in hr/employee apps. Context from MR !584 (2026-08-10): standard nav buttons + wheel scroll + tab-strip opts were unified here.

## Shared pieces (from MR !584)

- `CarouselNavButtons` + `CAROUSEL_TAB_STRIP_OPTS` live in `packages/ui/src/components/customs/CarouselNavButtons.tsx` (exported via index.ts). Tab-strip carousels MUST use the shared opts constant — do not re-declare per-file constants (`{ align: 'start', containScroll: 'trimSnaps', slidesToScroll: 'auto', dragFree: true, slides: '[data-slot="carousel-item"]' }`).
- Tab strip DOM pattern: `<Carousel className="relative w-full min-w-0 px-2 md:px-10" opts={CAROUSEL_TAB_STRIP_OPTS}><CarouselContent className="ml-0 flex-nowrap gap-N"><TabsList className="contents bg-transparent p-0">…<CarouselItem className="min-w-0 shrink-0 grow-0 basis-auto pl-0">…` — `display:contents` TabsList keeps Radix semantics while Embla measures slides.
- Drag-guard on every TabsTrigger inside a carousel: `onMouseDown={e => e.preventDefault()}` + `onClick={e => e.currentTarget.focus({ preventScroll: true })}`. Why it works: Radix Tabs auto-activates on focus, so dragging across a tab focuses it → accidental activation; preventDefault blocks the focus, onClick re-focuses for real clicks.

## Mouse wheel scrolling — use the hand-rolled handler, NOT a plugin

`Carousel.tsx` has a native wheel handler (do not replace with `embla-carousel-wheel-gestures`):

- That plugin only reacts when **deltaX is dominant** → touchpad horizontal + Chrome shift+wheel work, but plain mouse wheel (deltaY) and Firefox shift+wheel do NOT scroll → user reported it broken.
- Embla 8.6 public API has **no `scrollBy(distance)`** — only `scrollPrev()/scrollNext()/scrollTo(index, jump?)`. `scrollTo` animates between snaps (not a hard jump).
- Working pattern (keep): `useEffect` on `[api]`; viewport node = `api.containerNode().parentNode` (container = CarouselContent div, parent = viewport — same lookup the plugin used); add native `wheel` listener with `{ passive: false }`; `delta = Math.abs(deltaX) > Math.abs(deltaY) ? deltaX : deltaY`; skip when delta 0 or no scroll possible either way; `preventDefault()` ONLY when scrollable in that direction (`delta < 0 ? canScrollPrev() : canScrollNext()`), so the page scrolls again at boundaries; then `scrollPrev()/scrollNext()`.
- Cleanup removes the listener; effect deps `[api]` (api identity changes on re-init → re-attach).

## Pitfalls

- Wheel listener MUST be `{ passive: false }` — React's synthetic `onWheel` is passive (React 17+) and cannot `preventDefault()`.
- `onMouseDown` preventDefault also blocks native focus — always pair with the `onClick` focus re-add, or keyboard focus ring / active-tab state breaks.
- Rebuilding: MFE builds resolve `@hilo/ui` from **dist** — rebuild the package before typechecking/building hr/employee.
