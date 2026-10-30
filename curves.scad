// ============================================================================
// OpenSCAD Curved Train Track Generator
// ============================================================================
//
// Parametric LEGO-compatible curved train track. A single piece is composed of
// up to three stacked layers plus the track itself:
//
//   • Ballast buddy  (bottom, 96mm wide by default, red) — widest base plate
//   • Ballast plate  (middle, 64/80mm stepped by default) — the main ballast bed
//   • Rails + sleepers + endpoints (top)        — the track itself
//
// Each layer has LEGO studs on top and anti-studs (hollow tubes) underneath so
// pieces stack on standard LEGO baseplates and connect to each other.
//
// Units: millimetres. 1 LEGO stud = 8mm; Radius is expressed in studs so
// Radius = 40 means a 320mm curve radius at the track centerline.
//
// Coordinate frame (after curved_track() finishes):
//   • curved_track() translates by -Radius*8 in x so the piece starts at x=0
//     and sweeps counter-clockwise through the +y quadrant around (-R, 0).
//   • z=0 is the bottom of the sleepers. The top of the sleepers, the top of
//     the ballast plate and the base of the rails are all at z=3.2.
//
// Standard LEGO train radii (in studs):
//   24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120, 136, 152, 168, ...
//
// Command-line use (batch_generate.py / generate_stls.py rely on these names):
//   openscad -o out.stl -D Radius=40 -D SegAng=22.5 -D diverse=1800 \
//            -D generate_track=true -D generate_ballast=true \
//            -D generate_ballast_buddy=true curves.scad

// ============================================================================
// Configuration (shown in the OpenSCAD Customizer)
// ============================================================================

/* [Geometry] */
// Segment angle in degrees. 22.5 = 1/16 circle, 90 = quarter circle.
// The extra 0.0001 is deliberate: it keeps faces at the arc ends from landing
// exactly on coincident planes, which avoids CGAL slivers.
SegAng = 22.5001;
// Track radius in LEGO studs (1 stud = 8mm). 40 => 320mm curve radius.
Radius = 40; // [24:8:1024]
// Track gauge, as the number of studs between the rails. Sleepers, end
// connectors, ballast and print supports all follow it. Reference points:
// 4 = official LEGO gauge, 2 = official LEGO narrow gauge.
gauge_studs = 4; // [1:1:10]

/* [Detail] */
// Target arc length per sleeper gap (mm·deg). Lower = denser sleepers.
// sleeper_gap_count() caps sleepers at a 24mm pitch so adjacent sleepers never
// overlap, so very small values just saturate to that cap. No effect when
// generate_sleepers is off.
diverse = 1800; // [300:50:3000]

/* [Parts to output] */
generate_track         = true;  // rails, sleepers, endpoint connectors
generate_ballast       = true;  // the stepped middle ballast plate
generate_ballast_buddy = true;  // the widest bottom layer (needs generate_ballast)
// Sleepers under the rails. Off: no sleepers (and no sleeper pockets in the
// ballast); the ballast's studs take over the whole top layer, evenly spaced.
generate_sleepers = true;
// Technic axle cross holes through both ends of full track + ballast + buddy
// pieces.
technic_axle_holes = true;
// Whenever the ballast is generated: on = the snap peg and C-clip tab at each
// end; off = just the dovetail notch and peg hole cutouts. On ballast-only
// pieces "on" adds the peg and clip on their own so ballast pieces snap
// together. Track-only pieces always have the peg and clip.
clip_and_peg_on_ballast = false;

/* [Label] */
// Labels are engraved (mirrored, so they read from below) into the bottom of
// the piece: the buddy's underside, or the ballast's when there's no buddy.
// Track-only pieces have no labels. Each one can be turned on or off.
//
// Text to engrave on the outside of the curve, exactly as typed except that
// it's always upper-cased.
name = "ARON-TRACKS";
// Engrave the name on the outside of the curve.
label_name = true;
// Engrave the radius on the inside of the curve, e.g. "R40" for a 40-stud
// (320mm) radius.
label_radius = true;
// The settings below go on one line just above the radius label (toward
// the track center), in the order listed, separated by spaces. The text
// shrinks if the line would be longer than the piece.
//
// Engrave the segment angle in degrees, e.g. "22.5°".
label_angle = false;
// Engrave the gauge as studs between the rails, e.g. "G4" for standard LEGO
// gauge or "G2" for narrow gauge.
label_gauge = false;
// Engrave the diverse (sleeper density) setting, e.g. "D1800". Skipped when
// generate_sleepers is off, since diverse then has no effect.
label_diverse = false;
// Font used for every engraving.
label_font = "Liberation Sans:style=Bold";

/* [LEGO fit] */
// Diameter of the studs on top of the ballast plate and buddy. Real LEGO is
// 4.8mm; nudge this up/down to tune clutch for your printer.
stud_d = 4.8;
// Height of those studs.
stud_h = 1.8;
// Diameter of the mounting posts on top of sleepers and endpoint bases. These
// are slightly oversized relative to stud_d by default for a firmer grip.
post_d = stud_d + 0.1;
// Height of the sleeper / endpoint mounting posts.
post_h = 2;
// Outer / inner diameter of the anti-stud tubes under the ballast plate
// (3.2 / 1.5 matches the pins under 1xN LEGO plates).
antistud_od = 3.2;
antistud_id = 1.5;
// Facets on studs and anti-studs.
stud_fn = 24;
// Clearance (mm, per side) between a separately printed track and the seat
// cut for it in a ballast-only piece: added around the sleeper pockets, the
// rail channels and the end-connector seats so the track drops in. Raise it
// if the track is too tight, lower it if it's loose. Not used when the track
// and ballast are generated together (they're fused, so no gap is left).
track_fit_tol = 0.2; // [0:0.05:1]

// ============================================================================
// Internal geometry constants (do not edit unless you know what you're doing)
// ============================================================================

/* [Hidden] */
// LEGO grid pitch and plate height.
stud_pitch = 8;
plate_h    = 3.2;

// Rail spacing: center-to-center distance between the rails, mm. The rails
// sit half a stud outside the studs between them: 40 standard, 24 narrow.
track_gauge = (gauge_studs + 1) * stud_pitch;
// Radial offset of each rail from the centerline (20 at the default gauge).
// Sleeper and connector features are laid out around ±rail_offset; the swept
// rails themselves sit a further 0.025mm outboard (historic fit tuning).
rail_offset       = track_gauge / 2;
rail_sweep_offset = rail_offset + 0.025;
// Radial width of the between-rails region used by the ballast pockets.
between_rails_w   = track_gauge - 0.2;
// Endpoint connectors are offset this far radially from the centerline
// (sleepers sit exactly on it).
track_x_offset = -0.25;
// Sleeper footprint: tangential width and radial length. Sleepers run 12mm
// past each rail center (64mm at the default gauge); the ballast follows.
sleeper_w   = 16;
sleeper_len = track_gauge + 24;
// Radial offset of the sleeper / connector posts outboard of each rail.
outer_post_x = rail_offset + 8;
// Piece-to-piece coupler on each end connector, between the rails: a snap
// peg sitting in a dovetail notch on the inner-rail side and a dovetail tab
// with a C-shaped hole on the outer-rail side, this far either side of the
// centerline. The same as LEGO's own track; needs 2+ studs between the rails.
coupler_x = 8;
has_coupler = rail_offset >= 12;
// Minimum sleeper pitch (sleeper width + one stud pitch). Keeps neighbouring
// sleepers from overlapping and keeps between-sleeper studs on the LEGO grid.
min_sleeper_pitch = sleeper_w + stud_pitch;

// Full ballast plate thickness (2 LEGO plate heights).
ballast_thickness = 2 * plate_h;
// Vertical offset applied to the ballast stack so the ballast top ends up at
// z=3.2 (= sleeper top / rail base) and the bottom of the buddy sits at z=-4.8.
ballast_offset_z = -plate_h;

// Ballast layer widths (radial extent, mm), derived from the track width
// (sleeper_len): the top layer matches the sleepers and each layer below
// steps out one stud per side. 64 / 80 / 96 at the default gauge.
ballast_top_width    = sleeper_len;
ballast_mid_width    = ballast_top_width + 2 * stud_pitch;
ballast_bottom_width = ballast_mid_width + 2 * stud_pitch;

// Radial offsets (from the centerline) of the studs between the rails: as
// many 8mm-pitch studs as fit between the rail feet, centered. The rail foot
// is 3.9mm either side of the rail center. Default: [-12, -4, 4, 12].
rail_foot_half_w   = 3.9;
between_rails_clear = 2 * rail_sweep_offset - 2 * rail_foot_half_w;
between_rails_n     = floor((between_rails_clear - stud_d) / stud_pitch) + 1;
between_rails_offsets =
  [for (j = [0:between_rails_n - 1]) (j - (between_rails_n - 1) / 2) * stud_pitch];

// ============================================================================
// Math helpers
// ============================================================================

// Arc length (mm) → angle (deg) at radius r, and back.
function arc_deg(len, r) = len / r * 180 / PI;
function arc_len(deg, r) = r * deg * PI / 180;

// Upper-case the ASCII letters in a string.
function upper(s) = chr([for (c = s) let (o = ord(c)) (o >= 97 && o <= 122) ? o - 32 : o]);

// $fn for arc sweeps. See arc_sweep() for why this is capped.
function arc_fn(r) = min(9 * r, 1800);

// Number of sleeper-to-sleeper gaps along an arc of seg_ang degrees at radius
// r (mm). There are (n - 1) sleepers in the middle; the endpoint connectors
// occupy the two ends. Driven by `diverse` but capped by min_sleeper_pitch.
function sleeper_gap_count(r, seg_ang) =
  min(round(r * seg_ang / diverse),
      max(1, floor(seg_ang / arc_deg(min_sleeper_pitch, r))));

// Angle of each sleeper's centerline: evenly spaced, sleeper_gap_count()
// gaps along the arc (the endpoint connectors take the two ends).
// Empty when generate_sleepers is off.
function sleeper_angles(r, seg_ang) =
  let (g = sleeper_gap_count(r, seg_ang))
  generate_sleepers ? [for (i = [1:1:g - 1]) i * seg_ang / g] : [];

// ---------------------------------------------------------------------------
// Stud grid
// ---------------------------------------------------------------------------
// The buddy and mid-step rows are each spaced like a normal LEGO grid at
// their own radius: evenly, with the pitch along that row as close to 8mm as
// fits, so the inner rows aren't squeezed. All rows start and end on
// the same radial lines, 4mm (at the centerline) in from each end where the
// connector posts are, so the rows line up at both ends and are symmetric.
// curve_rad is the centerline radius, r the row's radius.
function row_end_angle(curve_rad) = arc_deg(4, curve_rad);
function row_n(curve_rad, seg_ang, r) =
  max(2, round(arc_len(seg_ang - 2 * row_end_angle(curve_rad), r) / stud_pitch) + 1);
function row_angle(curve_rad, seg_ang, r, k) =
  row_end_angle(curve_rad)
  + k * (seg_ang - 2 * row_end_angle(curve_rad)) / (row_n(curve_rad, seg_ang, r) - 1);

// ============================================================================
// Shared helper modules
// ============================================================================

// A LEGO stud. Defaults to the top-surface studs; pass post_d / post_h for the
// sleeper and endpoint mounting posts.
module stud(d = stud_d, h = stud_h) {
  cylinder(d = d, h = h, $fn = stud_fn);
}

// An anti-stud — a hollow tube that slots between studs on a LEGO plate.
module antistud(od = antistud_od, id = antistud_id, h = 3.3, hollow_h = 1.6) {
  difference() {
    cylinder(d = od, h = h, $fn = stud_fn);
    translate([0, 0, -0.01])
      cylinder(d = id, h = hollow_h + 0.01, $fn = stud_fn);
  }
}

// rotate_extrude wrapper that applies the standard $fn cap.
//
// Why the cap: OpenSCAD's CGAL exporter has a precision-collapse bug where a
// rotate_extrude(angle < 360) at very high $fn (roughly > 7000), when combined
// with *any* boolean union, flattens the inner radial wall to its chord. We
// cap at min(9*curve_rad, 1800) which is still plenty smooth (≥1.9mm segment
// length at the largest radii) and well below the bug threshold.
module arc_sweep(seg_angle, curve_rad) {
  rotate_extrude(angle = seg_angle, convexity = 10, $fn = arc_fn(curve_rad))
    children();
}

// Repeat children once per sleeper, each rotated to that sleeper's angle
// (see sleeper_angles()). The endpoint connectors are placed separately.
module each_sleeper(curve_rad, seg_angle) {
  for (a = sleeper_angles(curve_rad, seg_angle))
    rotate([0, 0, a])
      children();
}

// 2D pocket for one sleeper in the ballast: the sleeper's straight
// rectangular footprint plus tol on each side (and 1mm past each end, to open
// cleanly through the ballast edges), centered on curve_rad.
module sleeper_footprint(curve_rad, tol) {
  translate([curve_rad - sleeper_len / 2 - 1, -sleeper_w / 2 - tol])
    square([sleeper_len + 2, sleeper_w + 2 * tol]);
}

// --- Curved text ---
// Text is laid out one character at a time along the arc, so it follows the
// curve, with each character's advance width taken from Liberation Sans Bold's
// metrics (the same as Arial Bold's) so the spacing along the arc is the
// font's own, not squeezed or stretched. Widths are in 1/1000 em; OpenSCAD's
// text(size = s) has an em of 1.389 * s (measured).
text_em_per_size = 1.389;
text_cap_height  = 0.955;  // cap height / size (measured on "H")
text_chars  = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz°";
text_widths = [278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278,
               556, 556, 556, 556, 556, 556, 556, 556, 556, 556,
               333, 333, 584, 584, 584, 611, 975,
               722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833,
               722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611,
               333, 278, 333, 584, 556,
               556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889,
               611, 611, 611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500,
               400];

// Advance width (mm) of one character / a whole string at a text size.
function char_width(c, size) =
  let (i = search(c, text_chars)[0])
  (i == undef || i == [] ? 556 : text_widths[i]) / 1000 * text_em_per_size * size;
function text_width(s, size) = sum([for (c = s) char_width(c, size)]);
function sum(v, i = 0) = i >= len(v) ? 0 : v[i] + sum(v, i + 1);

// Engrave text along the arc, centered on its middle, at the given radial
// offset from the centerline (negative = inside the curve, positive =
// outside). z places the bottom of the 1mm extrusion. The text is mirrored so
// it reads from below, and shrinks if it would take up more than 85% of the
// arc at that radius.
module arc_text(text_str, curve_rad, radial_offset, z, seg_angle, size) {
  r  = curve_rad + radial_offset;
  sz = min(size, 0.85 * arc_len(seg_angle, r) / max(text_width(text_str, 1), 0.001));
  total = text_width(text_str, sz);
  for (i = [0:1:len(text_str) - 1]) {
    w = char_width(text_str[i], sz);
    // Arc length from the middle of the text to the middle of this character
    s = text_width([for (j = [0:1:i - 1]) text_str[j]], sz) + w / 2 - total / 2;
    rotate([0, 0, seg_angle / 2 + arc_deg(s, r)])
      translate([r, 0, z])
        rotate([0, 0, -90]) mirror([1, 0, 0])
          linear_extrude(height = 1.0)
            translate([-w / 2, -text_cap_height * sz / 2])
              text(text_str[i], size = sz, font = label_font,
                   halign = "left", valign = "baseline");
  }
}

// Split a string into words at spaces.
function split_words(s, i = 0, cur = "", out = []) =
  i >= len(s) ? (cur == "" ? out : concat(out, [cur]))
  : s[i] == " " ? split_words(s, i + 1, "", cur == "" ? out : concat(out, [cur]))
  : split_words(s, i + 1, str(cur, s[i]), out);

// Greedy word wrap: lines no wider than avail (mm) at this text size, where
// possible (a single word wider than avail gets a line to itself).
function wrap_words(words, size, avail, i = 0, cur = "", lines = []) =
  i >= len(words) ? (cur == "" ? lines : concat(lines, [cur]))
  : let (t = cur == "" ? words[i] : str(cur, " ", words[i]))
    (cur != "" && text_width(t, size) > avail)
      ? wrap_words(words, size, avail, i, "", concat(lines, [cur]))
      : wrap_words(words, size, avail, i + 1, t, lines);

// Largest text size (up to size) at which the words wrap into at most
// max_lines lines that all fit in avail.
function wrap_fit_size(words, size, avail, max_lines) =
  let (l = wrap_words(words, size, avail))
  (size <= 2 || (len(l) <= max_lines && max([for (x = l) text_width(x, size)]) <= avail))
    ? size : wrap_fit_size(words, size * 0.92, avail, max_lines);

// The underside labels (see the [Label] settings): "R##" on the inside of the
// curve, the settings line just above it, and the name on the outside.
// Subtract from a layer's bottom face.
// edge is the radial half-width of the layer being engraved; a long name
// wraps onto extra lines toward it.
module piece_labels(curve_rad, seg_angle, z, edge) {
  r_radius = -(ballast_top_width / 2 - 2);
  if (label_radius)
    arc_text(str("R", round(curve_rad / stud_pitch)), curve_rad, r_radius, z, seg_angle, 8);

  // Name: word-wrapped if it's longer than 85% of the arc. The last line sits
  // where a one-line name does; earlier lines stack outward (above it) as far
  // as the layer's edge allows, and the text shrinks if it still doesn't fit.
  if (label_name) {
    words = split_words(upper(name));
    r_name = ballast_top_width / 2 - 4;
    avail  = 0.85 * arc_len(seg_angle, curve_rad + r_name);
    sz0    = 6;
    pitch0 = 1.25 * sz0;
    max_lines = max(1, floor((edge - 0.5 - text_cap_height * sz0 / 2 - r_name) / pitch0) + 1);
    if (len(words) > 0) {
      sz    = wrap_fit_size(words, sz0, avail, max_lines);
      lines = wrap_words(words, sz, avail);
      n     = len(lines);
      for (j = [0:n - 1])
        arc_text(lines[j], curve_rad, r_name + (n - 1 - j) * 1.25 * sz, z, seg_angle, sz);
    }
  }

  // Settings line, 7.5mm toward the track center from the radius label: far
  // enough to clear it, and still outside the sleeper pockets between the
  // rails. Same font and size as the name (shrinks to fit, see arc_text()).
  parts = [if (label_angle)    str(round(seg_angle * 100) / 100, "°"),
           if (label_gauge)    str("G", gauge_studs),
           if (label_diverse && generate_sleepers) str("D", diverse)];
  if (len(parts) > 0)
    arc_text(join(parts, " "), curve_rad, r_radius + 7.5, z, seg_angle, 6);
}

// Join a list of strings with a separator.
function join(list, sep, i = 0) =
  i >= len(list) ? "" : str(i > 0 ? sep : "", list[i], join(list, sep, i + 1));

// The rows between the rails instead all share the same radial lines (8mm
// apart at the centerline), so their studs form straight rows across the track
// that LEGO tiles (e.g. wood-look sleeper tiles) fit on. The top-layer rows
// outside the rails are spaced at their own radius, like the buddy and mid
// step.
//
// With sleepers, top-layer studs are centered in each sleeper gap:
// gap_stud_count() of them per gap, as many as clear the sleepers / end
// connectors on that row (for the between-rails lines: on the innermost
// between-rails row, so every line is complete). Gaps under min_sleeper_pitch
// get none, as their studs would sit off the LEGO grid relative to the
// sleeper posts. Without sleepers the top-layer rows run the whole length,
// skipping spots too close to the end connectors.
gap_clear = sleeper_w / 2 + stud_d / 2 + 0.1;  // body half-width + stud radius

// Do m studs, spaced 8mm apart at radius rp, fit centered in a gap of
// gap_ang degrees on a row at radius r?
function gap_stud_fits(r, rp, gap_ang, m) =
  r * sin(gap_ang / 2 - arc_deg((m - 1) * stud_pitch / 2, rp)) >= gap_clear;
function gap_stud_count(curve_rad, seg_angle, r, rp, m = 1) =
  let (gap_ang = seg_angle / sleeper_gap_count(curve_rad, seg_angle))
  arc_len(gap_ang, curve_rad) < min_sleeper_pitch ? 0
  : !gap_stud_fits(r, rp, gap_ang, m) ? m - 1
  : m >= 20 ? m
  : gap_stud_count(curve_rad, seg_angle, r, rp, m + 1);

// One row of studs at radial offset o from the centerline and height z.
module stud_row(curve_rad, seg_angle, o, z) {
  r       = curve_rad + o;
  top     = abs(o) <= sleeper_len / 2;
  between = abs(o) < rail_offset;
  // Radius the stud spacing along the row is worked out at.
  rp = between ? curve_rad : r;
  if (!top || !generate_sleepers) {
    for (k = [0:row_n(curve_rad, seg_angle, rp) - 1])
      let (a = row_angle(curve_rad, seg_angle, rp, k))
      if (!top || r * sin(min(a, seg_angle - a)) >= gap_clear)
        rotate([0, 0, a]) translate([r, 0, z]) stud();
  } else {
    g = sleeper_gap_count(curve_rad, seg_angle);
    // Between the rails, size the lines on the innermost between-rails row.
    r_fit = between ? curve_rad - max([for (b = between_rails_offsets) abs(b)]) : r;
    m = gap_stud_count(curve_rad, seg_angle, r_fit, rp);
    for (i = [1:g], j = [0:1:m - 1])
      rotate([0, 0, (i - 0.5) * seg_angle / g
                    + arc_deg((j - (m - 1) / 2) * stud_pitch, rp)])
        translate([r, 0, z]) stud();
  }
}

// Breakaway support that holds a rail end up during printing: a 0.5mm-thick
// vertical plate (width × height, standing in the x-z plane) plus a stiffening
// rib and a foot strip that stick out 2mm sideways. ribs_pos_y = true puts
// them on the +y side, false on the -y side; callers point them into the piece.
module rail_support(width, height, ribs_pos_y = true) {
  rotate([90, 0, 0]) {
    cube([width, height, 0.5]);
    dz = ribs_pos_y ? -2 : 0;
    translate([0, 0, dz]) cube([0.5, height, 2]);    // vertical rib
    translate([0, 0, dz]) cube([width, 0.5, 2]);     // foot
  }
}

// Cross-shaped hole for a LEGO Technic axle. 10mm tall so it cuts through
// whatever it's subtracted from.
module technic_hole() {
  cube([5, 2, 10], center = true);
  cube([2, 5, 10], center = true);
}

// ============================================================================
// Track geometry modules
// ============================================================================

// 2D cross-section of a single rail, swept along the arc by curved_rails().
// Drawn in the rotate_extrude frame: x is radial, y becomes vertical.
// fill_foot fills the U-shaped recess under the rail foot so the rail sits
// flat on the ballast instead of leaving a hollow channel.
module rail_profile(fill_foot = false) {
  if (fill_foot)
    translate([-2.5, -4.3 + 1.5, 0]) square([5, 2]);
  translate([0, 1.5, 0]) polygon(
      points = [
        [1, 4.7],     [1, 4.5],      [1.2, 4.5],    [1.2, 0.4],
        [1.6, -0.7],  [3, -1.1],     [3, -1.7],     [3.9, -1.7],
        [3.9, -4.7],  [2.6, -4.7],   [2.6, -4.3],   [2.5, -4.3],
        [2.5, -2.3],  [-2.5, -2.3],  [-2.5, -4.3],  [-2.6, -4.3],
        [-2.6, -4.7], [-3.9, -4.7],  [-3.9, -1.7],  [-3, -1.7],
        [-3, -1.1],   [-1.6, -0.7],  [-1.2, 0.4],   [-1.2, 4.5],
        [-1, 4.5],    [-1, 4.7],     [-0.1, 4.7],   [-0.1, 4.5],
        [0.1, 4.5],   [0.1, 4.7],    [1, 4.7],
      ], convexity = 10);
}

// The two rails swept along the arc at the correct gauge. curve_rad is in mm.
module curved_rails(curve_rad, seg_angle, fill_foot = false) {
  arc_sweep(seg_angle, curve_rad) {
    translate([curve_rad - rail_sweep_offset, 0, 0]) rail_profile(fill_foot);  // inner
    translate([curve_rad + rail_sweep_offset, 0, 0]) rail_profile(fill_foot);  // outer
  }
}

// Right-side rail endpoint: the connector pad that the next piece's left
// endpoint slides into. off_l / off_h are print-fit tolerances. Like the left
// one it stops short of the bed, leaving a hollow under each rail end that the
// neighbour's rail end slots into.
module rail_endpoint_right() {
  off_l = 0.5;
  off_h = -0.15;
  poly = [[2.4, 2], [2.4, 6], [3.2 + off_h, 6], [3.2 + off_h, 4], [9.4, 4],
          [9.4, 3.1], [7, 3.1], [4, 2], [3.2 + off_h, 2]];
  translate([0, off_l, 0]) rotate([90, -90, 180]) linear_extrude(8 - off_l) polygon(poly);
}

// Left-side rail endpoint: the complementary shape to rail_endpoint_right().
module rail_endpoint_left() {
  off_l = 0.5;
  off_h = 0.515;
  poly = [[3 + off_h, 8], [3 + off_h, 4], [9.4, 4], [9.4, 3.05],
          [7, 3.05], [4, 1], [3 + off_h, 1]];
  translate([0, off_l, 0]) rotate([90, -90, 180]) linear_extrude(8 - off_l) polygon(poly);
}

// Trapezoidal (dovetail) prism cut out of the endpoint base.
module attach_poly(h) {
  off_l = 0.3;
  linear_extrude(h)
    polygon([[-off_l, 0], [2 - off_l, 1.9], [6 + off_l, 1.9], [8 + off_l, 0]]);
}

// Connector base sitting under a pair of rail endpoints, centered radially on
// the origin and spanning the sleeper length. Has mounting posts on top and
// the piece-to-piece coupler (see coupler_x). peg_and_clip adds the snap peg
// and C-clip tab; without them only the notch and hole cutouts remain.
// stud_recesses hollows the underside below each post so the connector can sit
// on a LEGO baseplate.
module endpoint_base(peg_and_clip = true, stud_recesses = false) {
  off = 0.1;  // taper of the peg and hole (top/bottom radius delta)
  cap_w = sleeper_len / 2 - (rail_offset + 4);  // 8mm at the default gauge
  difference() {
    union() {
      // Mounting posts: one outboard of each rail, the rest between the rails
      for (x = concat([-outer_post_x], between_rails_offsets, [outer_post_x]))
        translate([x, 0, 3]) stud(d = post_d, h = post_h);
      // End caps outboard of the rails
      translate([-sleeper_len / 2, -4, 0]) cube([cap_w + 0.3, 8, plate_h]);
      translate([rail_offset + 4, -4, 0])  cube([cap_w, 8, plate_h]);
      // Central support rail
      translate([-(rail_offset - 4), 0, 0]) cube([2 * rail_offset - 7, plate_h, plate_h]);
      // Connection plate, with the dovetail notch cut from its end edge
      difference() {
        translate([-(rail_offset - 4.2), -4, 0]) cube([2 * rail_offset - 4.4, 8, plate_h]);
        if (has_coupler)
          translate([-coupler_x - 4, -4.11, -0.5]) attach_poly(4);
      }
      if (has_coupler && peg_and_clip) {
        // Hollow, slightly tapered snap peg standing in the notch, bridged
        // back to the plate.
        translate([-coupler_x, 0, 0])
          difference() {
            union() {
              translate([0, -2.2, 0]) cylinder(h = plate_h, r = 1, $fn = 32);
              translate([0, -4, 0]) cylinder(h = plate_h, r1 = 1.9 - off, r2 = 1.9 + off, $fn = 32);
            }
            translate([0, -4, -0.5]) cylinder(h = 4, r = 1, $fn = 32);
          }
        // Dovetail tab sticking out of the end edge (the hole below turns it
        // into a C-clip the neighbour's peg snaps into)
        translate([coupler_x - 4, -3.4, 0]) mirror([0, 1, 0]) attach_poly(plate_h);
      }
    }
    // Tapered hole for the neighbour's peg
    if (has_coupler)
      translate([coupler_x, -3.8, -0.5]) cylinder(h = 4, r1 = 2.1 + off, r2 = 2.1 - off, $fn = 32);
    // Recesses under the posts. The between-rails ones are rounded on the
    // quadrant facing the nearest coupler feature so they clear it.
    if (stud_recesses) {
      for (x = [-outer_post_x, outer_post_x])
        translate([x - 2.5, -2.5, -1]) cube([5, 5, plate_h]);
      for (x = between_rails_offsets) {
        toward = (x < 0 ? -coupler_x : coupler_x) > x ? 1 : -1;
        translate([x, 0, 0]) {
          for (qx = [-1, 1], qy = [-1, 1])
            if (!(qx == toward && qy == -1))
              translate([min(qx, 0) * 2.5, min(qy, 0) * 2.5, -1]) cube([2.5, 2.5, plate_h]);
          translate([0, 0, -1]) cylinder(d = 5, h = plate_h, $fn = stud_fn);
        }
      }
    }
  }
}

// Complete connector block for one end of a piece, centered radially on the
// origin: both rail endpoints plus the base under them.
module full_endpoint(peg_and_clip = true, stud_recesses = false) {
  translate([-(rail_offset + 4), -8, 0]) rail_endpoint_left();
  translate([rail_offset - 4, -8, 0])    rail_endpoint_right();
  endpoint_base(peg_and_clip, stud_recesses);
}

// Just the coupler from endpoint_base(): the snap peg and the C-clip tab plus
// the strip of base along the end edge that holds them. Used for
// clip_and_peg_on_ballast. Same local frame as full_endpoint().
module coupler_only() {
  if (has_coupler)
    intersection() {
      endpoint_base();
      translate([-coupler_x - 4.6, -7, -1]) cube([2 * coupler_x + 9.2, 4.5, plate_h + 2]);
    }
}

// Breakaway supports under the snap peg and C-clip tab, which stick out past
// the end edge, from z0 up to their undersides at z = 0. Same local frame as
// full_endpoint(); the ribs point away from the piece so they don't fuse to it.
module coupler_supports(z0) {
  if (has_coupler) {
    translate([-coupler_x - 1.5, -5, z0]) rail_support(3, -z0, ribs_pos_y = false);
    translate([coupler_x - 4, -5, z0])    rail_support(8, -z0, ribs_pos_y = false);
  }
}

// Position children at the start (angle 0) / end (angle seg_angle) connector
// slot of an arc of radius curve_rad. The end slot is rotated 180° so the
// connector faces outward. The end slot sits 0.5mm further out than the start
// one: intentional fit tuning, the two ends are not exact mirror images.
module at_arc_start(curve_rad) {
  translate([curve_rad + track_x_offset, 4, 0]) children();
}
module at_arc_end(curve_rad, seg_angle) {
  rotate([0, 0, seg_angle])
    translate([curve_rad + track_x_offset + 0.5, -4, 0])
      rotate([0, 0, 180]) children();
}

// A single sleeper (crosstie), centered radially on the origin: a 3-segment
// sleeper with mounting posts on top and six underside cutouts.
// simplified_bottom skips the underside cutouts so the sleeper fuses cleanly
// with the ballast plate.
module sleeper(simplified_bottom = false) {
  g = rail_offset;
  {
    skip  = 0.3;                        // overlap so the segments union cleanly
    cap_w = sleeper_len / 2 - (g + 4);  // end-cap width (8mm by default)
    difference() {
      union() {
        // Three body segments: two end caps outboard of the rails and a middle
        // plate between them, leaving an 8mm gap under each rail.
        translate([-sleeper_len / 2, -8, 0]) cube([cap_w + skip, sleeper_w, plate_h]);
        translate([-(g - 4) - skip, -8, 0])  cube([2 * (g - 4) + 2 * skip, sleeper_w, plate_h]);
        translate([g + 4 - skip, -8, 0])     cube([cap_w + skip, sleeper_w, plate_h]);
        // Mounting posts on top in two rows at y = ±4: one outboard of each
        // rail plus the between-rails grid (12 posts by default).
        for (x = concat([-outer_post_x], between_rails_offsets, [outer_post_x]), y = [-4, 4])
          translate([x, y, 3]) stud(d = post_d, h = post_h);
      }
      if (!simplified_bottom)
        for (y = [-6.5, 1.5]) {
          translate([-(g + 10.5), y, -1]) cube([5, 5, plate_h]);
          translate([-(g - 5), y, -1])    cube([2 * (g - 5), 5, plate_h]);
          translate([g + 5.5, y, -1])     cube([5, 5, plate_h]);
        }
    }
  }
}

// ============================================================================
// Ballast plate — the stepped middle layer with studs on top
// ============================================================================
//
// Cross-section (local frame, before ballast_offset_z), default widths:
//   • Top layer  ballast_top_width (64mm) × 6.4mm thick (z = 0 … 6.4)
//   • Mid step   ballast_mid_width (80mm) × 3.2mm thick (z = 0 … 3.2)
// The widths follow the track width (sleeper_len) and the [Ballast] settings.
//
// The top half is cut where the rails, endpoints and sleepers sit. The bottom
// half also gets sleeper pockets when printed stand-alone (with_track=false).
//
// Parameters:
//   curve_rad  — curve radius in mm.
//   seg_angle  — arc angle in degrees.
//   with_track — the track is fused on top: skip the stand-alone sleeper
//                pockets so the track merges into the plate.
//   has_buddy  — a ballast buddy is underneath: it carries the labels, the
//                anti-studs and the stud-lock slots instead of this plate.
module ballast_plate(curve_rad, seg_angle, with_track = false, has_buddy = false) {
  half_t         = ballast_thickness / 2;
  // Clearance around the track's seat; none when the track is fused on.
  fit_tol        = with_track ? 0 : track_fit_tol;
  step_w         = (ballast_mid_width - ballast_top_width) / 2;  // 8mm by default
  tangential_inset = 4;    // stud-lock slot / anti-stud distance from the arc ends
  slot_depth       = 2.0;  // stud-lock slot depth

  union() {
    difference() {
      // Stepped body: full-thickness top layer plus a half-height step on
      // each side. The inner step overlaps the top layer by 4mm.
      arc_sweep(seg_angle, curve_rad) {
        translate([curve_rad - ballast_top_width / 2, 0, 0])
          square([ballast_top_width, ballast_thickness]);
        translate([curve_rad - ballast_mid_width / 2, 0, 0])
          square([step_w + 4, half_t]);
        translate([curve_rad + ballast_top_width / 2, 0, 0])
          square([step_w, half_t]);
      }

      if (!has_buddy)
        piece_labels(curve_rad, seg_angle, -0.1, ballast_mid_width / 2);

      // ---- Top-half seat for the track ----
      // Project rails + endpoints + sleepers to 2D, extrude back up, and keep
      // only the part inside the top half of the top layer.
      intersection() {
        translate([0, 0, half_t])
          arc_sweep(seg_angle, curve_rad)
            translate([curve_rad - ballast_top_width / 2, 0, 0])
              square([ballast_top_width, half_t + 20]);

        translate([0, 0, -10])
          linear_extrude(height = ballast_thickness + 20) {
            // Rails and end connectors, grown by fit_tol for a separate track.
            offset(delta = fit_tol)
              projection(cut = false) {
                translate([0, 0, plate_h - ballast_offset_z])
                  curved_rails(curve_rad, seg_angle, fill_foot = true);
                translate([0, 0, -ballast_offset_z]) {
                  at_arc_start(curve_rad) full_endpoint();
                  at_arc_end(curve_rad, seg_angle) full_endpoint();
                }
              }
            // Sleeper pockets: the sleepers' own straight footprint plus
            // fit_tol each side, so the walls are flat and match the
            // bottom-half pockets below (no wedge-shaped slivers between them).
            each_sleeper(curve_rad, seg_angle)
              sleeper_footprint(curve_rad, fit_tol);
            // Extend the cut past the arc ends so the endpoint connector nubs
            // are cleanly removed rather than leaving rounded leftovers.
            extension_width = sleeper_len + stud_pitch;
            translate([curve_rad - extension_width / 2, -4, 0])
              square([extension_width, 12]);
            rotate([0, 0, seg_angle])
              translate([curve_rad - extension_width / 2, -8, 0])
                square([extension_width, 24]);
          }
      }

      // Stud-lock slots on the underside at both arc ends, sized for the
      // studs of a 1xN plate as wide as the mid step (only when printed
      // alone, with no buddy).
      if (!with_track && !has_buddy) {
        slot_len = ballast_mid_width - stud_d / 2;
        translate([curve_rad - slot_len / 2, tangential_inset - stud_d / 2, -0.1])
          cube([slot_len, stud_d, slot_depth]);
        rotate([0, 0, seg_angle])
          translate([curve_rad - slot_len / 2, -tangential_inset - stud_d / 2, -0.1])
            cube([slot_len, stud_d, slot_depth]);
      }

      // Bottom-half sleeper pockets between the rails (stand-alone only).
      if (!with_track)
        intersection() {
          arc_sweep(seg_angle, curve_rad)
            translate([curve_rad - between_rails_w / 2, -between_rails_w / 2, 0])
              square([between_rails_w, between_rails_w]);
          translate([0, 0, -1])
            linear_extrude(height = half_t + 1)
              each_sleeper(curve_rad, seg_angle)
                sleeper_footprint(curve_rad, fit_tol);
        }
    }

    // ---- Added features ----

    // Anti-studs under each arc end, matching a 1xN LEGO plate as wide as the
    // mid step (N-1 tubes fit between its N studs; 9 for the default 80mm).
    // The buddy has these instead when present.
    if (!has_buddy) {
      n_tubes    = round(ballast_mid_width / stud_pitch) - 1;
      antistud_x = [for (i = [0:n_tubes - 1]) (i - (n_tubes - 1) / 2) * stud_pitch];
      for (x = antistud_x)
        translate([curve_rad + x, tangential_inset, -0.1]) antistud();
      rotate([0, 0, seg_angle])
        for (x = antistud_x)
          translate([curve_rad + x, -tangential_inset, -0.1]) antistud();
    }

    // Studs, all on the stud grid (see stud_row()): a row along each
    // edge of the mid-step shelf, a row just inside each sleeper end on the
    // top layer, and the between-rails grid on the top layer.
    for (o = [-1, 1] * (ballast_mid_width / 2 - 4))
      stud_row(curve_rad, seg_angle, o, half_t);
    for (o = concat([-1, 1] * (sleeper_len / 2 - 4), between_rails_offsets))
      stud_row(curve_rad, seg_angle, o, ballast_thickness);
  }
}

// ============================================================================
// Ballast buddy — the widest bottom layer (ballast_bottom_width, 96mm default)
// ============================================================================
//
// Sits directly under the ballast plate, extending one ballast step further
// on each side.
// 1.6mm thick, with a row of studs along each edge. When the track and
// ballast are fused on top, the labels are engraved here instead.
//
// Parameters:
//   curve_rad  — curve radius in mm.
//   seg_angle  — arc angle in degrees.
//   with_label — engrave the labels (see [Label]) on the bottom face.
module ballast_buddy(curve_rad, seg_angle, with_label = false) {
  buddy_t = ballast_thickness / 4;
  difference() {
    translate([0, 0, -buddy_t])
      arc_sweep(seg_angle, curve_rad)
        translate([curve_rad - ballast_bottom_width / 2, 0, 0])
          square([ballast_bottom_width, buddy_t]);
    if (with_label)
      piece_labels(curve_rad, seg_angle, -buddy_t - 0.1, ballast_bottom_width / 2);
  }
  // A row along each edge, on the shared stud layout.
  for (o = [-1, 1] * (ballast_bottom_width / 2 - 4))
    stud_row(curve_rad, seg_angle, o, 0);
}

// ============================================================================
// curved_track — assemble one complete curved track segment
// ============================================================================
//
// Parameters:
//   radius_studs — radius in LEGO studs (multiplied by stud_pitch internally).
//   seg_angle    — arc angle in degrees.
//
// Produces a single curved piece starting at x=0 and sweeping counter-clockwise.
module curved_track(radius_studs, seg_angle) {
  R       = radius_studs * stud_pitch;
  fused   = generate_track && generate_ballast;
  // Snap peg + C-clip tab on the connectors (see clip_and_peg_on_ballast).
  peg_and_clip  = !generate_ballast || clip_and_peg_on_ballast;
  ballast_clips = clip_and_peg_on_ballast && generate_ballast && !generate_track;
  // The buddy only sits under the ballast plate; it's never generated alone.
  buddy = generate_ballast_buddy && generate_ballast;
  if (generate_ballast_buddy && !generate_ballast)
    echo("WARNING: generate_ballast_buddy needs generate_ballast; skipping the buddy.");
  if (generate_track && !generate_sleepers && !generate_ballast)
    echo("WARNING: no sleepers and no ballast: the rails are only held by the end connectors.");

  echo(str("Arc length at centerline: ", arc_len(seg_angle, R), " mm, ",
           len(sleeper_angles(R, seg_angle)), " sleepers"));

  translate([-R, 0, 0])
    difference() {
      union() {
        // --- Ballast layers ---
        if (buddy)
          color("Red")
            translate([0, 0, ballast_offset_z])
              ballast_buddy(R, seg_angle, with_label = generate_ballast);

        if (generate_ballast)
          color("Gray")
            translate([0, 0, ballast_offset_z])
              ballast_plate(R, seg_angle,
                            with_track = fused,
                            has_buddy = buddy);

        // --- Track (rails + endpoints + sleepers) ---
        if (generate_track)
          color("DarkSlateGray") {
            // Rails, trimmed back 4mm at each end where the endpoint
            // connectors take over.
            difference() {
              translate([0, 0, plate_h])
                curved_rails(R, seg_angle, fill_foot = generate_ballast);
              trim_w = sleeper_len + 2 * stud_pitch;  // wide enough to catch both rails
              translate([R + track_x_offset - trim_w / 2, 0, 0]) cube([trim_w, 4, 20]);
              rotate([0, 0, seg_angle])
                translate([R + track_x_offset + trim_w / 2, 0, 0])
                  rotate([0, 0, 180]) cube([trim_w, 4, 20]);
            }

            each_sleeper(R, seg_angle)
              translate([R, 0, 0])
                sleeper(simplified_bottom = generate_ballast);

            // When fused with ballast, fill under the rails so the piece is
            // one continuous body. Stops fill_end_inset mm (arc length) short
            // of each end so it can't fill the endpoint peg holes, which
            // reach 2.6mm in from the ends. 0.1mm narrower than the ballast's
            // top layer on each side so its faces don't sit exactly on the
            // ballast's (which shows as flickering strips in preview).
            if (generate_ballast) {
              fill_end_inset = 4;
              inset_ang = arc_deg(fill_end_inset, R);
              rotate([0, 0, inset_ang])
                arc_sweep(max(0, seg_angle - 2 * inset_ang), R)
                  translate([R - sleeper_len / 2 + 0.1, -2.3, 0])
                    square([sleeper_len - 0.2, 5.4]);
            }
          }

        // --- End connectors ---
        // With nothing underneath, they get stud recesses so they can sit on
        // a LEGO baseplate.
        if (generate_track)
          color("DarkSlateGray") {
            at_arc_start(R) full_endpoint(peg_and_clip, stud_recesses = !generate_ballast);
            at_arc_end(R, seg_angle) full_endpoint(peg_and_clip, stud_recesses = !generate_ballast);
          }
        if (ballast_clips)
          color("Gray") {
            at_arc_start(R) coupler_only();
            at_arc_end(R, seg_angle) coupler_only();
          }

        // Breakaway print supports. They stand on the bottom of the piece
        // (0.02mm below it): the buddy's underside, else the ballast's, else
        // the sleepers' (z = 0).
        piece_bottom = buddy            ? ballast_offset_z - ballast_thickness / 4
                     : generate_ballast ? ballast_offset_z
                     :                    0;
        support_z = piece_bottom - 0.02;
        // Under the rail-end clips, just outside each arc end, positioned
        // relative to each rail, up to just under the clip overhang: 2.08 for
        // the short supports, 3.23 for the tall ones.
        if (generate_track) {
          short_h = 2.08 - support_z;
          tall_h  = 3.23 - support_z;
          g = rail_offset;
          translate([R + g - 2.2, -3, support_z]) rail_support(4, short_h);
          translate([R - g - 3.3, -3, support_z]) rail_support(3, tall_h);
          rotate([0, 0, seg_angle]) {
            translate([R + g + 0.2, 3, support_z]) rail_support(3, tall_h, ribs_pos_y = false);
            translate([R - g - 1.8, 3, support_z]) rail_support(4, short_h, ribs_pos_y = false);
          }
        }
        // Under the snap peg and C-clip tab, when ballast leaves them hanging
        // above the bed.
        if (((generate_track && peg_and_clip) || ballast_clips) && piece_bottom < 0) {
          at_arc_start(R) coupler_supports(support_z);
          at_arc_end(R, seg_angle) coupler_supports(support_z);
        }
      }

      // Technic axle holes through both arc ends (full assembly only), under
      // the outermost between-rails stud positions.
      if (technic_axle_holes && fused && buddy)
        for (r = between_rails_n > 1
                   ? [between_rails_offsets[0], between_rails_offsets[between_rails_n - 1]]
                   : [between_rails_offsets[0]]) {
          translate([R + r, 4, -0.8]) rotate([90, 0, 0]) technic_hole();
          rotate([0, 0, seg_angle])
            translate([R + r, -4, -0.8]) rotate([90, 0, 0]) technic_hole();
        }
    }
}

// ============================================================================
// Output
// ============================================================================

curved_track(Radius, SegAng);

// Layout templates for viewing several pieces side by side in the editor.
// (`%` = transparent background shape, `#` = highlighted debug shape.)
//%translate([-384, 0, 0])    curved_track(24, 45);        // R24 L45
//%translate([-320, 0, 0])    curved_track(32, SegAng);
//%translate([-256, 0, 0])    curved_track(40, 36.87);     // R40 for switch geometry
//%translate([-192, 0, 0])    curved_track(48, SegAng);
//%translate([-128, 0, 0])    curved_track(56, 18);        // R56 L18
//%translate([-64, 32*8, 0]) rotate([0, 0, 21]) mirror([1, 0, 0]) curved_track(56, 21);  // R56 switch
//%translate([64, 0, 0])      curved_track(80, SegAng);
//%translate([128, 0, 0])     curved_track(88, 11.25);     // R88 L11.25
//%translate([192, 0, 0])     curved_track(96, SegAng);
//%translate([0, 0, 0])       curved_track(104, 11.25);    // R104 L11.25
//%translate([320, 0, 0])     curved_track(112, SegAng);
//%translate([384, 0, 0])     curved_track(120, 11.25);    // R120 L11.25
