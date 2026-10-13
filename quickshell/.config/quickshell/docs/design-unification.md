# Design unification — 26 September 2026

Keep the shell compact, rectangular, readable, and predictable. Favor shared
primitives over extra effects or a larger configuration surface.

## Applied in this pass

- Clock, calendar navigation, notification actions, update actions, and Tailscale
  refresh/copy controls now use `StyledButton`. Local wrappers only express
  domain state; they no longer duplicate painting or input behavior.
- `StyledButton` honors its public `font` property, including text measurement,
  while icon glyphs retain their icon font.
- Clock and weather section headings use `SectionHeading`. Clock and notification
  separators use `Divider`; the shared divider is no longer almost invisible.
- The notification heading and actions occupy separate rows. A bounded list area
  replaces sizing driven by a fill-height scroll view's implicit size. Missing
  notification fields use empty values rather than self-referential bindings.
- Calendar navigation and return-to-current-month are keyboard controls. Tailscale
  refresh/copy controls and service switches have descriptive accessible names.
- Updates use shared spacing tokens and the compact heading/button treatment.

## Rules for subsequent edits

- Use `StyledButton`, `StyledSwitch`, `SectionHeading`, and `Divider` for ordinary
  controls and section structure. Extend these primitives for recurring needs.
- Keep cyan for selection/focus. Keep status colors for actual service state.
- Use monospace UI labels and the existing typography/spacing tokens.
- Disabled actions must look disabled; icon-only controls need an accessible name.
- Preserve keyboard focus, service-owned state, and existing actions when changing
  presentation. Test actions with mocks when they affect network or power state.
- Keep panel widths appropriate to their content. Uniformity does not require
  forcing a calendar, a process table, and an authentication prompt into one size.

## Next priorities (not implemented by this pass)

1. **Text fields.** Updates, Mullvad, SingBox, Waydroid, and Network each paint their
   own fields. Extract a shared field for ordinary search/input first. Keep the
   authentication and picker focus/password contracts separate during migration.
2. **Metric rows.** CPU/GPU/memory/disk panels repeat label/value layouts, separators,
   and muted text conventions. Consolidate those rows while retaining units and
   meaningful differences between graphs and process tables.
3. **Narrow-screen bar behavior.** Both module runs currently request their natural
   width. Define an explicit overflow strategy, then test small logical widths,
   long status strings, and enlarged fonts without losing workspace controls.
4. **Remaining specialized controls.** Audio sliders, device lists, app tiles, and
   calendar day selection need a focused keyboard/focus audit. Do not replace them
   with generic buttons unless their selection and gesture behavior remains intact.

## Validation

Shared-control regression tests and shell contracts pass. All 96 QML files lint
cleanly with the installed Pinentry import path. Clock/calendar panels were rendered
for inspection in an isolated offscreen window. Live shell logs confirm successful
reload; backend actions were not triggered during presentation validation.

## Module pass — 27 September 2026

The previous next-priority list is superseded by this review record. Shared
`StyledTextField` and `StyledSlider` now cover ordinary fields and sliders.
Password authentication and picker focus contracts remain specialized.

| Module | Changes / review outcome |
| --- | --- |
| Clock / calendar | Shared navigation; keyboard day selection; today/selection cyan. |
| Notifications | Shared actions, bounded list, keyboard activation/expansion/dismissal. |
| Weather | Correct snow-code precedence; wrapping failure state and retry. |
| BTC | Refresh remains available on initial failure; chart repaint on theme/size changes. |
| CPU / GPU | Retained meaningful per-core/process tables; unavailable GPU readings show `--`. |
| Memory / disk | Honest zero-based percentage bars; bounded fill; long mount labels handled. |
| Audio | Shared keyboard sliders and mute buttons; unavailable output state. |
| Media | Capability-aware buttons and seek; empty state; seek committed on release. |
| Night light | Shared switches/sliders; release commits retain the dragged value. |
| Network | Shared password field, keyboard rows, connection failures, distinct empty/off states. |
| Tailscale | Shared actions and keyboard exit-node rows. |
| Mullvad / Waydroid | Shared ordinary text fields; existing specialized views retained. |
| SingBox | Shared route actions/search; routing command semantics retained. |
| Podman | Shared refresh; transitional status takes precedence over unhealthy color. |
| Updates / Codex usage | Shared fields/actions; keyboard package links and accessible refresh. |
| Tray | Menu-only items open their menu on left click. |
| Power | Shared detail actions; capture action before closing the delegate. |
| OSD | Height follows scaled content plus margin; plain text. |
| Workspaces / title / layout | Preserved layout; plain text, bounded special labels, readable hover. |
| Idle inhibitor | User-preferred ☕ / 💤 restored; readable hover preserved. |
| Mouse DPI | Existing specialized controls retained after review. |
| Lock | See lock-resume-review.md; lifecycle fixes take priority over cosmetic changes. |

Keyboard, theme replacement, slider binding/commit, popup bounds and Escape tests
pass. Service failure and shell-contract regressions pass. These checks do not
exercise real power, connection, route, or device mutations. Narrow-screen bar
overflow and broader metric-row extraction remain separate follow-up work.

Offscreen visual inspection covered all 21 detail panels at their natural sizes,
including unavailable-backend states. It found and corrected a stretched slider
track, fractional text measurement clipping a selected route label, and a hardware
disabled message shown when no Wi-Fi adapter exists. The preview is isolated from
the desktop bus; backend error text in it is not evidence of a live service fault.

## Panel typography contract

All detail panels and notification surfaces use shared semantic roles from Theme:

| Role | Default | Use |
| --- | --- | --- |
| `panelTitleSize` | 14 px, bold | Panel title / content title |
| `panelBodySize` | 12 px | Rows, controls, ordinary values; bold for section headings |
| `panelCaptionSize` | 11 px | Supporting metadata, timestamps, captions |
| `panelValueSize` | 18 px | Summary metrics |
| `panelReadoutSize` | 28 px | Primary clock, timer, price, temperature readouts |

Use monospace throughout these panels. Supporting text uses the shared secondary
opacity rather than per-module faint values. Icon glyphs retain optical sizing;
bar text and the full-screen lock retain their own scales. The panel roles derive
from existing theme overrides; avoid introducing new per-module size choices.
