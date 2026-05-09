/// Breakpoints used by every responsive layout in the example. Centralised
/// so all panels reflow at the same widths.
class Breakpoints {
  static const double phoneMax   = 720;
  static const double tabletMax  = 1100;

  static bool isPhone(double w)   => w <  phoneMax;
  static bool isTablet(double w)  => w >= phoneMax && w < tabletMax;
  static bool isDesktop(double w) => w >= tabletMax;
}
