"""Applies LOWEST vertices/drawcalls + reversed filter to Generic Depth addon.
Run from repo root: python apply_lowest_heuristic.py [reshade-dir]
Idempotent - safe to run twice.
Works against UPSTREAM crosire/reshade@main (original, unmodified).
"""
import sys
from pathlib import Path

target = Path(sys.argv[1] if len(sys.argv) > 1 else ".") / "examples" / "09-depth" / "generic_depth_addon.cpp"
text = target.read_text(encoding="utf-8")

def replace_once(old: str, new: str):
    global text
    count = text.count(old)
    if count != 1:
        raise AssertionError(f"expected 1 occurrence, found {count} for: {old[:80]!r}")
    text = text.replace(old, new)

def replace_once_any(candidates: list[str], new: str):
    global text
    for old in candidates:
        if old in text:
            count = text.count(old)
            if count != 1:
                raise AssertionError(f"expected 1 occurrence, found {count} for variant: {old[:80]!r}")
            text = text.replace(old, new)
            return
    raise AssertionError(f"expected one of {candidates[0][:80]!r} ... to appear exactly once")

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
\t\t\treturn drawcalls > other.drawcalls;

\t\treturn (drawcalls_indirect < (drawcalls / 3) ?""",
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
\t\t\treturn drawcalls < other.drawcalls;

\t\treturn (drawcalls_indirect < (drawcalls / 3) ?""")

# 3) copy decision in on_clear_depth_impl - inverted <= for lowest modes
replace_once(
"""\t\t\t\t// Use greater equals operator here to handle case where the same scene is first rendered into a shadow map and then for real (e.g. Mirror's Edge main menu)
\t\t\t\tdo_copy = current_stats.vertices >= state.best_copy_stats.vertices || (op == clear_op::fullscreen_draw && current_stats.drawcalls >= state.best_copy_stats.drawcalls);""",
"""\t\t\t\tif (s_draw_stats_heuristic == draw_stats_heuristic::lowest_vertices || s_draw_stats_heuristic == draw_stats_heuristic::lowest_drawcalls)
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

# 4) ImGui combo items for draw stats heuristic
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

# 5) Add reversed filtering config variable after FilterFormat
# Upstream: comment line has no tab, static vars have NO leading tabs either
replace_once_any([
    """// Enable or disable the format check from 'check_depth_format' in the detection heuristic
static unsigned int s_format_filtering = 0;
static unsigned int s_custom_resolution_filtering[2] = {};""",
    """// Enable or disable the format check from 'check_depth_format' in the detection
static unsigned int s_format_filtering = 0;
static unsigned int s_custom_resolution_filtering[2] = {};""",
], """// Enable or disable the format check from 'check_depth_format' in the detection heuristic
static unsigned int s_format_filtering = 0;
static unsigned int s_custom_resolution_filtering[2] = {};
static unsigned int s_reversed_filtering = 0;""")

# 6) Add reversed filtering logic in on_begin_render_effects selection
replace_once(
"""\t\tif (s_format_filtering != 0 && !check_depth_format(info.desc.texture.format))
\t\t\tcontinue;
\t\tif (s_aspect_ratio_heuristic != aspect_ratio_heuristic::none && !check_aspect_ratio(static_cast<float>(info.desc.texture.width), static_cast<float>(info.desc.texture.height), static_cast<float>(frame_width), static_cast<float>(frame_height)))
\t\t\tcontinue; // Not a good fit

\t\tif (selected_depth_stencil.handle == 0 ||""",
"""\t\tif (s_format_filtering != 0 && !check_depth_format(info.desc.texture.format))
\t\t\tcontinue;
\t\tif (s_aspect_ratio_heuristic != aspect_ratio_heuristic::none && !check_aspect_ratio(static_cast<float>(info.desc.texture.width), static_cast<float>(info.desc.texture.height), static_cast<float>(frame_width), static_cast<float>(frame_height)))
\t\t\tcontinue; // Not a good fit

\t\t// Filter by reversed depth buffer detection
\t\tconst bool is_reversed = info.last_frame_stats.reversed_clear_value;
\t\tif (s_reversed_filtering == 1 && !is_reversed)
\t\t\tcontinue; // Only allow reversed
\t\tif (s_reversed_filtering == 2 && is_reversed)
\t\t\tcontinue; // Exclude reversed

\t\tif (selected_depth_stencil.handle == 0 ||""")

# 7) Add config loading for FilterReversed
replace_once(
"""\treshade::get_config_value(nullptr, "DEPTH", "FilterFormat", s_format_filtering);
\treshade::get_config_value(nullptr, "DEPTH", "FilterResolutionWidth", s_custom_resolution_filtering[0]);
\treshade::get_config_value(nullptr, "DEPTH", "FilterResolutionHeight", s_custom_resolution_filtering[1]);

\tif (s_aspect_ratio_heuristic > aspect_ratio_heuristic::match_custom_resolution_exactly)""",
"""\treshade::get_config_value(nullptr, "DEPTH", "FilterFormat", s_format_filtering);
\treshade::get_config_value(nullptr, "DEPTH", "FilterReversed", s_reversed_filtering);
\treshade::get_config_value(nullptr, "DEPTH", "FilterResolutionWidth", s_custom_resolution_filtering[0]);
\treshade::get_config_value(nullptr, "DEPTH", "FilterResolutionHeight", s_custom_resolution_filtering[1]);

\tif (s_aspect_ratio_heuristic > aspect_ratio_heuristic::match_custom_resolution_exactly)""")

# 8) Add ImGui combo for reversed filtering
replace_once(
"""\tif (ImGui::Combo("Filter by depth buffer format", reinterpret_cast<int *>(&s_format_filtering), depth_format_items, static_cast<int>(std::size(depth_format_items))))
\t{
\t\treshade::set_config_value(nullptr, "DEPTH", "FilterFormat", s_format_filtering);
\t\tforce_reset = true;
\t}

\tif (bool copy_before_clear_operations = s_preserve_depth_buffers != 0;
\t\tImGui::Checkbox("Copy depth buffer before clear operations", &copy_before_clear_operations))""",
"""\tif (ImGui::Combo("Filter by depth buffer format", reinterpret_cast<int *>(&s_format_filtering), depth_format_items, static_cast<int>(std::size(depth_format_items))))
\t{
\t\treshade::set_config_value(nullptr, "DEPTH", "FilterFormat", s_format_filtering);
\t\tforce_reset = true;
\t}

\tconst char *const reversed_items[] = {
\t\t"Any",
\t\t"Prefer reversed",
\t\t"Exclude reversed"
\t};
\tif (ImGui::Combo("Filter by reversed depth", reinterpret_cast<int *>(&s_reversed_filtering), reversed_items, static_cast<int>(std::size(reversed_items))))
\t{
\t\treshade::set_config_value(nullptr, "DEPTH", "FilterReversed", s_reversed_filtering);
\t\tforce_reset = true;
\t}

\tif (bool copy_before_clear_operations = s_preserve_depth_buffers != 0;
\t\tImGui::Checkbox("Copy depth buffer before clear operations", &copy_before_clear_operations))""")

# 9) clamp loaded config for draw stats heuristic (robustness)
old_clamp = '\treshade::get_config_value(nullptr, "DEPTH", "DrawStatsHeuristic", reinterpret_cast<unsigned int &>(s_draw_stats_heuristic));'
new_clamp = old_clamp + '\n\tif (s_draw_stats_heuristic > draw_stats_heuristic::lowest_drawcalls)\n\t\ts_draw_stats_heuristic = draw_stats_heuristic::prefer_vertices;'
if old_clamp in text and new_clamp not in text:
    text = text.replace(old_clamp, new_clamp)

target.write_text(text, encoding="utf-8")
print(f"patched {target}")