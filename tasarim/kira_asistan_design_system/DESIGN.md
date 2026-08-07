---
name: Kira Asistanı Design System
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
  on-surface-variant: '#414944'
  inverse-surface: '#303030'
  inverse-on-surface: '#f3f0f0'
  outline: '#717974'
  outline-variant: '#c0c8c3'
  surface-tint: '#396755'
  primary: '#023727'
  on-primary: '#ffffff'
  primary-container: '#1f4e3d'
  on-primary-container: '#8ebea8'
  inverse-primary: '#a0d1bb'
  secondary: '#4c6455'
  on-secondary: '#ffffff'
  secondary-container: '#cbe6d4'
  on-secondary-container: '#506859'
  tertiary: '#3f2c00'
  on-tertiary: '#ffffff'
  tertiary-container: '#5c4100'
  on-tertiary-container: '#e4aa1d'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#bbedd6'
  primary-fixed-dim: '#a0d1bb'
  on-primary-fixed: '#002116'
  on-primary-fixed-variant: '#204f3e'
  secondary-fixed: '#cee9d6'
  secondary-fixed-dim: '#b2cdbb'
  on-secondary-fixed: '#082014'
  on-secondary-fixed-variant: '#344c3e'
  tertiary-fixed: '#ffdea4'
  tertiary-fixed-dim: '#fabd32'
  on-tertiary-fixed: '#261900'
  on-tertiary-fixed-variant: '#5d4200'
  background: '#fcf9f8'
  on-background: '#1b1c1c'
  surface-variant: '#e4e2e1'
typography:
  display-lg:
    fontFamily: Montserrat
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Montserrat
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-md:
    fontFamily: Montserrat
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Montserrat
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-md:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  result-value:
    fontFamily: Montserrat
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 40px
---

## Brand & Style

The design system is built for a high-utility rent increase calculator, emphasizing precision, legality, and financial trust. The personality is "The Reliable Consultant"—knowledgeable and calm, avoiding the anxiety often associated with financial adjustments.

The visual style follows a **Modern Corporate** approach with a **Tactile** twist. It leverages the structured logic of Material 3 but replaces the default sterility with a warm, editorial aesthetic. It uses high-contrast typography and a grounded color palette to ensure information hierarchy is immediate. 

Key principles:
- **Clarity Over Ornament:** Every element serves the calculation or the interpretation of the result.
- **Organic Professionalism:** Using cream backgrounds and forest greens to create a more human, less "bank-like" atmosphere.
- **Structural Integrity:** Relying on thin borders and 8dp alignment rather than shadows to define space.

## Colors

The palette is anchored by **Deep Forest Green**, signaling growth and stability. This is contrasted against a **Warm Cream** background to reduce eye strain and provide a premium, paper-like feel.

- **Primary (#1F4E3D):** Used for primary actions, active navigation states, and key brand moments.
- **Secondary Sage (#8FA998/E8EDE8):** Used for non-critical surfaces, secondary buttons, and tonal backgrounds to separate content sections without using harsh lines.
- **Neutral Charcoal (#2D2D2D):** Used for all primary text to ensure maximum legibility against the cream background.
- **Functional Amber (#F0B429):** Used for warnings or "Pro" features. It provides a soft alert that doesn't feel punitive.

## Typography

This design system uses a dual-font strategy. **Montserrat** provides a strong, geometric presence for headings and numerical results, conveying authority. **Hanken Grotesk** is used for body text and labels, chosen for its contemporary feel and exceptional readability in data-heavy contexts.

For the "Result Typography," the weight is pushed to Bold to ensure the user's primary goal (the calculated rent) is the undisputed focal point of the screen.

## Layout & Spacing

The system follows a strict **8dp grid**. All component heights and margins must be multiples of 8. 

- **Grid Model:** 4-column fluid grid for mobile; 12-column fixed grid (max-width 1200px) for desktop.
- **Vertical Rhythm:** Use 24px (3x base) between major sections and 8px (1x base) between related elements like labels and inputs.
- **Touch Targets:** All interactive elements maintain a minimum height of 48px.

## Elevation & Depth

This design system eschews traditional shadows in favor of **Tonal Layering** and **Thin Borders**.

1.  **Level 0 (Background):** The main Warm Cream (#F7F4EF) surface.
2.  **Level 1 (Card/Surface):** Use Soft Sage (#E8EDE8) or a White surface with a 1px border in Primary (at 10% opacity).
3.  **Depth Indicators:** Instead of a shadow, use a subtle "bottom-heavy" border on buttons (1.5px) to give a tactile, pressed-paper feel.
4.  **No Blurs:** Background blurs and glassmorphism are strictly prohibited to maintain the "utility" look.

## Shapes

The shape language is "Soft Professional." 
- **Standard Radius:** 12px for inputs and small cards.
- **Large Radius:** 24px for Pro Cards and bottom sheets.
- **Buttons:** 12px radius, avoiding full pills to maintain a more structured, architectural look.
- **Segments:** The inner indicator of a segmented control should have a radius 4px smaller than its container.

## Components

### Navigation
- **AppBar:** Clean text-based titles using `headline-sm`. No shadow; uses a 1px bottom border in Sage.
- **Bottom Navigation:** 4 tabs (Hesapla, Oranlar, Geçmiş, Ayarlar). Icons use 2pt strokes. Active state uses the Primary color for both icon and label.

### Buttons
- **Primary Button:** Solid Forest Green (#1F4E3D) with White text. High-contrast, no shadow.
- **Outlined Button:** 1px border in Forest Green, transparent background.
- **Secondary/Ghost Button:** Soft Sage background with Forest Green text for low-priority actions.

### Inputs & Selection
- **Text Input:** 12px rounded corners. 1px border in Sage, turning Forest Green on focus. Labels sit above the field in `label-lg`.
- **Date Selector:** A modal sheet using a calendar view with Primary color accents on the selected date.
- **Segmented Control:** A Sage-colored track with a solid White or Cream sliding indicator for switching calculation modes.

### Feedback & Info
- **Info/Warning Banners:** Soft Amber (#F0B429) background with Dark Charcoal text. Used for "TÜFE" rate warnings or legal disclaimers.
- **List Rows:** 72px height, 1px bottom divider in Sage. Use `body-md` for the title and `label-md` for secondary metadata.

### Pro Features
- **Pro Badge:** Small capsule, Amber background, 10px uppercase bold text.
- **Pro Card:** Uses a subtle Forest Green border (2px) and a very light Sage tint to differentiate it from standard utility cards. Include a "locked" icon variant.