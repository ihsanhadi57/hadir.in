# Design System Documentation: The Digital Concierge

## 1. Overview & Creative North Star

**Creative North Star: The Seamless Flow**

This design system is built to move away from the rigid, boxed-in layouts of traditional SaaS. For an event attendance and ticketing platform, the UI must feel like a high-end concierge: invisible until needed, authoritative when present, and exceptionally fluid.

We achieve a "High-End Editorial" experience by prioritizing **negative space over dividers** and **tonal depth over borders**. By utilizing intentional asymmetry—such as offset headers and varied card widths—we break the "template" feel, creating an interface that feels bespoke, premium, and purposefully designed.

---

## 2. Color Language & The "No-Line" Philosophy

The color palette is anchored in high-contrast precision. While the core is a crisp `background` (#f9f9ff), the depth is found in the interplay of neutral tiers.

### The "No-Line" Rule

**Explicit Instruction:** Designers are prohibited from using 1px solid borders to section content. Boundaries must be defined solely through background color shifts or subtle tonal transitions.

- To separate a sidebar from a main feed, transition from `surface-container-low` to `surface`.

- To highlight a ticket detail, place a `surface-container-lowest` card on a `surface-container-high` background.

### Surface Hierarchy & Nesting

Treat the UI as physical layers of fine paper.

- **Layer 0 (Base):** `background` (#f9f9ff).

- **Layer 1 (Main Content Areas):** `surface-container-low`.

- **Layer 2 (Floating Cards/Tickets):** `surface-container-lowest` (Pure White).

- **Layer 3 (Modals/Popovers):** `surface-bright` with high-diffusion ambient shadows.

### The "Glass & Gradient" Rule

To elevate the "Tech-Startup" aesthetic, use Glassmorphism for floating elements (like a sticky attendance-count bar). Use `surface-variant` at 70% opacity with a `24px` backdrop blur.

**Signature Texture:** Primary CTAs should not be flat. Use a linear gradient from `primary` (#004ac6) to `primary_container` (#2563eb) at a 135-degree angle to provide a sense of "soul" and luminosity.

---

## 3. Typography & Editorial Cadence

Our typography strategy uses a "Dual-Type" system to balance authority with utility.

- **Display & Headlines (Manrope):** Use Manrope for all `display-` and `headline-` scales. This font’s geometric nature conveys a modern, architectural feel.
  - _Director’s Note:_ Use `display-lg` for hero ticketing numbers or event titles to create a high-impact, editorial entrance.

- **Body & Labels (Inter):** Use Inter for all functional data (attendee names, timestamps, settings). Inter is optimized for legibility at small sizes, ensuring that high-density attendance lists remain readable.

- **Hierarchy as Identity:** The massive contrast between a `display-md` headline and `label-md` metadata creates a sense of "Information Architecture" that feels curated rather than cluttered.

---

## 4. Elevation & Depth: Tonal Layering

We convey hierarchy through **Tonal Layering** rather than traditional structural shadows.

- **The Layering Principle:** Depth is achieved by "stacking" the surface-container tokens. A `surface-container-lowest` card sitting on a `surface-container-low` section creates a natural, soft lift.

- **Ambient Shadows:** When an element must "float" (e.g., a scanned ticket confirmation), use a shadow color tinted with `on-surface` (#141b2b) at 6% opacity, with a blur radius of `32px`. Avoid grey/black shadows; they muddy the clean aesthetic.

- **The "Ghost Border" Fallback:** If a border is required for accessibility (e.g., in high-contrast modes), use the `outline-variant` token at 15% opacity. Never use 100% opaque borders.

- **Glassmorphism:** For top navigation bars, use `surface` at 80% opacity with a `backdrop-filter: blur(12px)`. This allows event imagery to bleed through, softening the layout's edges.

---

## 5. Signature Components

### Buttons & Interaction

- **Primary:** Gradient fill (`primary` to `primary-container`), `rounded-md` (0.375rem). No border. On hover, increase the gradient luminosity.

- **Secondary:** `surface-container-highest` fill with `on-surface` text. This feels integrated into the UI rather than "pasted on."

- **Tertiary:** Text-only using `primary` color, bold weight, with an underline that only appears on hover.

### Ticketing & Attendance Cards

- **Forbid Dividers:** Do not use lines to separate attendee rows. Use `16px` of vertical white space or alternating subtle shifts between `surface` and `surface-container-low`.

- **Status Indicators:** Use "The Glow." Instead of a simple green dot for "Attended," use a `success` (#10B981) indicator with a matching 4px soft outer glow to make it feel "active" and digital.

### Input Fields

- **State Transition:** Default state uses `surface-container-high` as a background. On focus, the background shifts to `surface-container-lowest` and gains a `primary` "Ghost Border" (20% opacity).

- **Error States:** Use `error` (#ba1a1a) for text and icons, but use `error_container` as a soft background wash for the entire input field.

### Event-Specific Components

- **The "Live Count" Chip:** A high-contrast pill using `inverse-surface` and `inverse-on-surface` typography to track real-time attendance at the top of the screen.

- **Glass Overlays:** For QR code scanners, use a full-screen `surface-dim` overlay at 40% opacity with a clear "cutout" to focus the user's eye.

---

## 6. Director’s Do’s and Don'ts

### Do:

- **Embrace White Space:** If a section feels crowded, increase the padding rather than adding a line.

- **Use Tonal Nesting:** Place `surface-container-high` elements inside `surface-container-low` parents to create "recessed" areas for secondary information.

- **Prioritize "The Scan":** Use `title-lg` for primary data points (e.g., Ticket ID) and `body-sm` for secondary labels (e.g., "Purchased 2 days ago").

### Don't:

- **Don't use "Pure Black":** Use `on-surface` (#141b2b) for text to maintain a premium, ink-like softness.

- **Don't use standard shadows:** If the shadow is visible enough to be "seen" rather than "felt," the opacity is too high.

- **Don't use 100% width buttons:** Keep CTAs contained and intentional. Use `width: fit-content` where possible to maintain the editorial feel.

- **Don't use Dividers:** If you feel the urge to draw a line between two pieces of content, use a `1px` shift in background color instead.
