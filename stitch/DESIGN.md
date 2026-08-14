---
name: KiraRota Design System
colors:
  surface: '#fcf9f8'
  surface-dim: '#dcd9d9'
  surface-bright: '#fcf9f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f2'
  surface-container: '#f0eded'
  surface-container-high: '#eae7e7'
  surface-container-highest: '#e4e2e1'
  on-surface: '#1b1c1c'
  on-surface-variant: '#434843'
  inverse-surface: '#303030'
  inverse-on-surface: '#f3f0f0'
  outline: '#737973'
  outline-variant: '#c3c8c1'
  surface-tint: '#4d6453'
  primary: '#061b0e'
  on-primary: '#ffffff'
  primary-container: '#1b3022'
  on-primary-container: '#819986'
  inverse-primary: '#b4cdb8'
  secondary: '#58605a'
  on-secondary: '#ffffff'
  secondary-container: '#dce5dd'
  on-secondary-container: '#5e6660'
  tertiary: '#171715'
  on-tertiary: '#ffffff'
  tertiary-container: '#2b2c2a'
  on-tertiary-container: '#949390'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d0e9d4'
  primary-fixed-dim: '#b4cdb8'
  on-primary-fixed: '#0b2013'
  on-primary-fixed-variant: '#364c3c'
  secondary-fixed: '#dce5dd'
  secondary-fixed-dim: '#c0c9c1'
  on-secondary-fixed: '#151d19'
  on-secondary-fixed-variant: '#404943'
  tertiary-fixed: '#e4e2de'
  tertiary-fixed-dim: '#c8c6c3'
  on-tertiary-fixed: '#1b1c1a'
  on-tertiary-fixed-variant: '#474744'
  background: '#fcf9f8'
  on-background: '#1b1c1c'
  surface-variant: '#e4e2e1'
typography:
  display-currency:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  display-currency-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  margin-mobile: 16px
  margin-desktop: 24px
  gutter: 12px
---

## Brand & Style
The design system is rooted in a **Modern Corporate** aesthetic with a **Tactile** twist, specifically tailored for property and financial management. It prioritizes reliability and organization while maintaining a welcoming atmosphere through a warm, organic color palette.

The visual language draws from Material 3 logic but leans into a more bespoke, editorial feel. It uses subtle tonal shifts and soft surface separations rather than aggressive lines to manage high information density. The goal is to make complex financial calculations feel approachable and transparent, reducing the cognitive load for landlords and property managers.

## Colors
The palette is dominated by the "Deep Forest" primary green, signaling stability and growth. The "Cream" background provides a warm, paper-like canvas that is easier on the eyes than pure white during long sessions of data entry.

- **Primary:** Use for key actions, active states, and branding elements.
- **Surface/Secondary:** Use for large container backgrounds and subtle groupings to differentiate property blocks.
- **Text:** Dark Charcoal is used for maximum contrast against the cream background.
- **Semantic Colors:** Reserved strictly for status indicators (Paid, Overdue, Expiring).

## Typography
This design system utilizes **Inter** for its exceptional legibility in data-heavy environments. The typographic scale is optimized for financial clarity.

**Financial Data Formatting:**
- Use `display-currency` for total monthly revenue and balances.
- Always use tabular numlining (tnum) features if available to ensure numbers align vertically in lists.
- Currency symbols should be the same weight as the amount but may be 80% of the font size to keep the focus on the value.

## Layout & Spacing
The layout follows a **Fluid Grid** model optimized for high-density Android devices. 

- **Grid:** 4-column grid for mobile, 8-column for tablets.
- **Vertical Rhythm:** An 8px baseline grid ensures consistent alignment of text and components.
- **Density:** Use "Compact" spacing for list items to allow more property entries to be visible at once. Use "Comfortable" spacing for summary dashboards to provide breathing room for key metrics.

## Elevation & Depth
Depth is communicated through **Tonal Layering** and soft, ambient shadows. 

- **Level 0 (Background):** Cream (#FDFBF7) for the main application canvas.
- **Level 1 (Cards):** Sage Green (#E8F1E9) with no shadow. Used for secondary content or inactive states.
- **Level 2 (Active Cards):** White (#FFFFFF) with a very soft, diffused 15% opacity Deep Forest Green shadow. Used for the primary summary and interactive property cards.
- **Floating Elements:** Primary Action Buttons (FABs) use a higher elevation with a more pronounced shadow to signify "create/add" actions.

## Shapes
A **Rounded** shape language is used to soften the professional tone. 

- **Standard Elements:** 8px (0.5rem) for cards and input fields.
- **Large Elements:** 16px (1rem) for bottom sheets and large container cards.
- **Buttons:** Fully pill-shaped (rounded-full) for primary actions to distinguish them from data containers.

## Components

### Summary Cards
High-contrast containers at the top of the dashboard. Use white backgrounds with Deep Forest Green text for the primary balance. Use a vertical "accent bar" (4px wide) on the left side of the card to denote the property category or status.

### List Items (Rentals)
Horizontal layout with a leading 40dp avatar/icon area (using Sage Green). Title (Tenant Name) in `label-lg`, Subtitle (Property Address) in `body-md`. The trailing edge is reserved for the rent amount in `label-lg` with a color-coded status indicator (dot) next to it.

### Buttons
- **Primary:** Deep Forest Green fill with Cream text. Pill-shaped.
- **Secondary:** Transparent with a 1px Sage Green border or Sage Green fill with Primary Green text.
- **Tertiary:** Text-only, Primary Green, for low-emphasis actions like "View History."

### Input Fields
Filled style (Material 3) using a very light Sage Green tint. The active indicator is a 2px bottom stroke in Primary Green. Labels move to a "floating" position on focus.

### Navigation Bar
A 5-tab persistent bottom bar. Icons use the Primary Green for the active state with a subtle "pill" indicator behind the icon. Inactive states use 60% opacity of the Neutral color.

### Financial Data Displays
A specialized component for displaying ROI, tax calculations, or yield. It uses a 2-column small grid within a card, featuring a `label-sm` header and a bolded `body-lg` value.