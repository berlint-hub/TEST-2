"""Applies LOWEST vertices/drawcalls heuristic to Generic Depth addon.
Run from repo root: python apply_lowest_heuristic.py [reshade-dir]
Idempotent - safe to run twice.
"""
import sys
from pathlib import Path

target = Path(sys.argv[1] if len(sys.argv) > 1 else ".") / "examples" / "09-depth" / "generic_depth_addon.cpp"
text = target.read_text(encoding="utf-8")

def replace_once(old: str, new: str):
    global text
    assert text.count(old) == 1, f"expected 1 occurrence, found {text.count(old)} for: {old[:80]!r}"
    text = text.replace(old, new)

# 1) enum - add lowest variants (keep 0,1,2 stable for existing presets)
replace_once(
"""enum class draw_stats_heuristic : unsigned int
{
\tprefer_vertices = 0,
\tvertices,
\tdrawcalls
};""",
"""enum class draw_stats_heuristic : unsigned int
{
\tprefer_vertices = 0,
\tvertices,
\tdrawcalls,
\tlowest_vertices,
\tlowest_drawcalls
};""")

# 2) operator> - inverted comparison + empty handling
replace_once(
"""\tbool operator>(const draw_stats &other) const
\t{
\t\tif (s_draw_stats_heuristic == draw_stats_heuristic::vertices)
\t\t\treturn vertices > other.vertices;
\t\tif (s_draw_stats_heuristic == draw_stats_heuristic::drawcalls)
\t\t\treturn drawcalls > other.drawcalls;""",
"""\tbool operator>(const draw_stats &other) const
\t{
\t\tconst bool is_empty = vertices == 0 && drawcalls == 0;
\t\tconst bool other_empty = other.vertices == 0 && other.drawcalls == 0;
\t\tif (is_empty != other_empty)
\t\t\treturn other_empty; // Any real stats are better than empty, regardless of heuristic

\t\tif (s_draw_stats_heuristic == draw_stats_heuristic::vertices)
\t\t\treturn vertices > other.vertices;
\t\tif (s_draw_stats_heuristic == draw_stats_heuristic::drawcalls)
\t\t\treturn drawcalls > other.drawcalls;
\t\tif (s_draw_stats_heuristic == draw_stats_heuristic::lowest_vertices)
\t\t\treturn vertices < other.vertices;
\t\tif (s_draw_stats_heuristic == draw_stats_heuristic::lowest_drawcalls)
\t\t\treturn drawcalls < other.drawcalls;""")

# 3) copy decision in on_clear_depth_impl - inverted <= for lowest modes
replace_once(
"""\t\t\t// Use greater equals operator here to handle case where the same scene is first rendered into a shadow map and then for real (e.g. Mirror's Edge main menu)
\t\t\t\tdo_copy = current_stats.vertices >= state.best_copy_stats.vertices || (op == clear_op::fullscreen_draw && current_stats.drawcalls >= state.best_copy_stats.drawcalls);""",
"""\t\t\tif (s_draw_stats_heuristic == draw_stats_heuristic::lowest_vertices || s_draw_stats_heuristic == draw_stats_heuristic::lowest_drawcalls)
\t\t\t\t{
\t\t\t\t\tconst bool best_empty = state.best_copy_stats.vertices == 0 && state.best_copy_stats.drawcalls == 0;
\t\t\t\t\t// Inverted logic for lowest heuristics: keep the smallest workload (e.g. for UI / small depth buffers)
\t\t\t\t\tdo_copy = best_empty || current_stats.vertices <= state.best_copy_stats.vertices || (op == clear_op::fullscreen_draw && current_stats.drawcalls <= state.best_copy_stats.drawcalls);
\t\t\t\t}
\t\t\t\telse
\t\t\t\t{
\t\t\t\t\t// Use greater equals operator here to handle case where the same scene is first rendered into a shadow map and then for real (e.g. Mirror's Edge main menu)
\t\t\t\t\tdo_copy = current_stats.vertices >= state.best_copy_stats.vertices || (op == clear_op::fullscreen_draw && current_stats.drawcalls >= state.best_copy_stats.drawcalls);
\t\t\t\t}""")

# 4) ImGui combo items
replace_once(
"""\tconst char *const draw_stats_heuristic_items[] = {
\t\t"Default",
\t\t"Higher vertices",
\t\t"Higher draw calls"
\t};""",
"""\tconst char *const draw_stats_heuristic_items[] = {
\t\t"Default",
\t\t"Higher vertices",
\t\t"Higher draw calls",
\t\t"Lowest vertices",
\t\t"Lowest draw calls"
\t};""")

# 5) clamp loaded config (robustness, optional - only if pattern exists)
old_clamp = '\treshade::get_config_value(nullptr, "DEPTH", "DrawStatsHeuristic", reinterpret_cast<unsigned int &>(s_draw_stats_heuristic));'
new_clamp = old_clamp + '\n\tif (s_draw_stats_heuristic > draw_stats_heuristic::lowest_drawcalls)\n\t\ts_draw_stats_heuristic = draw_stats_heuristic::prefer_vertices;'
if old_clamp in text and new_clamp not in text:
    text = text.replace(old_clamp, new_clamp)

target.write_text(text, encoding="utf-8")
print(f"patched {target}")
