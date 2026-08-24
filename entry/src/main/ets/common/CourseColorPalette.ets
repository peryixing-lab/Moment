/**
 * Stable per-course colour assignment for the visual timetable.
 *
 * Courses are not stored with a colour, so a colour is derived deterministically
 * from the course name: the same course always renders the same colour, and two
 * different courses almost never collide. This keeps the backup format and the
 * data model unchanged. All hues are soft harmonised tones that sit well with the
 * app's blue accent and the immersive materials used across the UI.
 */
export class CourseColorPalette {
  // Six-digit hex values, no leading '#'. Prepending an alpha byte yields the
  // soft fill used behind a course block.
  private static readonly BRAND_HEX: string[] = [
    '0A59F7', // Blue  (matches AppColors.ACCENT)
    '7C4DFF', // Purple
    '0F9D58', // Green
    'F2994A', // Amber
    'E75B8A', // Pink
    '11A7BD' // Teal
  ];

  /** Solid 6-digit colour for a course, e.g. '#0A59F7'. */
  static colorFor(name: string): string {
    const hex: string = CourseColorPalette.brandHex(name);
    return `#${hex}`;
  }

  /** Soft translucent fill (approx. 15% alpha) for a course block background. */
  static backgroundFor(name: string): string {
    const hex: string = CourseColorPalette.brandHex(name);
    return `#26${hex}`;
  }

  /** Soft translucent accent (approx. 10% alpha) for an inactive/disabled course. */
  static mutedBackgroundFor(name: string): string {
    const hex: string = CourseColorPalette.brandHex(name);
    return `#1F${hex}`;
  }

  private static brandHex(name: string): string {
    const palette: string[] = CourseColorPalette.BRAND_HEX;
    let hash: number = 0;
    const trimmed: string = name.trim();
    for (let index: number = 0; index < trimmed.length; index += 1) {
      hash = (hash * 31 + trimmed.charCodeAt(index)) >>> 0;
    }
    return palette[hash % palette.length];
  }
}
