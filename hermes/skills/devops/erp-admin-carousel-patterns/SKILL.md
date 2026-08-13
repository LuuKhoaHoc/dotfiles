---
name: erp-admin-carousel-patterns
description: "Use when editing erp-admin carousels/tab strips."
---

# erp-admin Carousel / Tab-Strip Patterns

Use when building, editing, or reviewing carousels and carousel-based tab strips in erp-admin (`@hilo/ui` Carousel = Embla 8.6 + Radix Tabs). Covers the standardized pattern applied repo-wide in MR !584 / issue #174 (10+ call sites across hr/employee), so NEW tab strips should copy it instead of inventing variants.

## Standard pattern (tab strip carousel)

- **Shared opts**: `CAROUSEL_TAB_STRIP_OPTS` from `@hilo/ui` (exported from `components/customs/CarouselNavButtons.tsx`) — `{ align: 'start', containScroll: 'trimSnaps', slidesToScroll: 'auto', dragFree: true, slides: '[data-slot="carousel-item"]' }`. NEVER define local EMBLA_OPTS copies (that was the bug this pattern fixed).
- **Layout**:
  ```tsx
  <Carousel className="relative w-full min-w-0 px-2 md:px-10" opts={CAROUSEL_TAB_STRIP_OPTS}>
    <CarouselContent className="ml-0 flex-nowrap gap-5">
      <TabsList className="contents bg-transparent p-0">
        {items.map((item) => (
          <CarouselItem key={item.key} className="min-w-0 shrink-0 grow-0 basis-auto pl-0">
            <TabsTrigger ... />
          </CarouselItem>
        ))}
      </TabsList>
    </CarouselContent>
    <CarouselNavButtons />
  </Carousel>
  ```
- `TabsList` with `display:contents` keeps Radix tab semantics while Embla measures slides from the flex track.
- **Nav buttons**: `CarouselNavButtons` (prev/next pair, auto-disabled via canScrollPrev/Next, `sr-only` labels). Don't inline `CarouselPrevious/Next` className copies.

## Drag must not activate the tab under the cursor

Radix Tabs auto-activates on **focus** (activationMode automatic) — dragging across tabs focuses them via mousedown, activating the wrong tab. Guard on every `TabsTrigger` inside a carousel:

```tsx
onMouseDown={(e) => { e.preventDefault(); }}
onClick={(e) => { e.currentTarget.focus({ preventScroll: true }); }}
```

`preventDefault` on mousedown blocks the natural focus (and thus auto-activation) during drag; the explicit focus in onClick restores it for real clicks. Keyboard (Tab/Enter/arrows) is unaffected.

## Mouse wheel scrolling (native-like)

Wheel handler lives in `ui/Carousel.tsx` itself (one place, applies to every carousel):

- `useEffect` attaching a native `wheel` listener `{ passive: false }` on the viewport node (`api.containerNode().parentNode`).
- `delta = Math.abs(deltaX) > Math.abs(deltaY) ? deltaX : deltaY` — covers plain mouse wheel (deltaY), shift+wheel (deltaX on Chrome, deltaY+shift on Firefox), and trackpad (deltaX).
- `delta < 0 ? api.scrollPrev() : api.scrollNext()` — animate between snaps.
- `preventDefault()` ONLY when the carousel can still scroll in that direction; otherwise the page scrolls (native-like boundary behavior).

## Pitfalls (learned the hard way)

- **`embla-carousel-wheel-gestures` plugin does NOT work for mouse wheel**: only activates when deltaX is dominant → touchpad works, plain wheel/shift+wheel don't. Tried 8.1.0 and removed it — do not re-add. (Also its transitive dep `wheel-gestures` is easy to drop from a hand-edited lockfile, causing runtime crash on clean install.)
- **Embla 8.6 public API has NO `scrollBy`** — only `scrollPrev()/scrollNext()/scrollTo(index, jump?)`. Scroll-by-pixels requires internal engine (fragile) — scroll by snap instead.
- **Mouse wheel regression on native→Embla conversion**: `overflow-x-auto` strips scrolled with the wheel natively; Embla doesn't until the handler above exists. Always check wheel scroll after converting a strip.
- **Converting a native-scroll strip**: keep `TabsTrigger` classes (CONFIG_TAB_TRIGGER_CLASS or inline group styles) intact; only the wrapper changes.
- Typecheck after touching `@hilo/ui`: rebuild the package first (`pnpm --filter @hilo/ui build`) — MFE typecheck resolves `@hilo/ui` types from `dist/`.
