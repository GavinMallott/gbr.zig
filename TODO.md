## To Do For gerber.zig


### Major Milestones:
- Create working IR
- Convert from IR to PNG
- Convert from IR to SVG
- Convert from IR to Raylib render
- Convert from IR back to gbr


#### Working IR:
- Add Attributes
- Add Step-Repeat
- Add circular plot support
    - Requires reworking move, plot, flash impl
- Finish AP Macro
    - Add Macro Aperture types
- Add AP Block support


### Planned Improvements:
- Replace std.mem.eql with std.mem.startsWith where applicable
- Used fixed-size stack-allocated buffers ([4096]u8)
- Replace ArrayLists with fixed buffers (MAX_SIZE defenitions somewhere)
- Early-Exit Evaluation (if (line[0] != 'D') continue;)
- Faster Float Parsing (presicion needed only to 5.6)
- Keyword hashmap lookup rather than std.mem.eql
- Or moving window slice scanning
- Arena allocator (test only)
- Pre-flatten input buffer (remove \n \r \t checking)