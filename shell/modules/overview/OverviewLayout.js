.pragma library

// Where each card goes on one screen.
//
// The overview is only useful if every window is as large as the screen
// allows, and every window keeps its own shape: a terminal squashed into the
// proportions of a browser is no longer recognisable at a glance. So the
// cards are laid out in rows and every row count from one to n is tried; the
// arrangement that covers the most screen wins.
//
// All cards share one frame height. Letting each row grow to fill its own
// width covered more pixels, but three windows came out as two thumbnails
// over one giant, which reads as "this one matters more" when it does not.
//
// Rows are filled in reading order of where the windows really are (top to
// bottom, then left to right), so a card lands near its window and the
// entrance animation travels a short, readable distance instead of crossing
// the screen.
//
// `wins` is [{ id, aspect, maxHeight, cx, cy }]: aspect is width / height,
// maxHeight the real height of the window (a card is never drawn larger than
// the window it stands for), cx/cy its centre on screen. `area` is
// { x, y, width, height } in the screen's own coordinates. `captionHeight` is
// the strip under each frame that carries the icon and title.
//
// Returns { <id>: { x, y, width, height, frameHeight } }.
function arrange(wins, area, gap, captionHeight) {
    let result = {}
    let n = wins.length
    if (n === 0 || area.width <= 0 || area.height <= 0) return result

    let ordered = wins.slice().sort((a, b) => {
        // Windows whose centres sit within a sliver of each other share a
        // line: maximized windows all have the same centre, and sorting them
        // by a pixel of difference would scramble a row for nothing.
        if (Math.abs(a.cy - b.cy) > 24) return a.cy - b.cy
        return a.cx - b.cx
    })

    let best = null
    for (let rows = 1; rows <= n; rows++) {
        let plan = planRows(ordered, rows, area, gap, captionHeight)
        // A clear improvement is needed to add a row: at equal coverage the
        // flatter arrangement reads more easily.
        if (!best || plan.coverage > best.coverage * 1.02) best = plan
    }

    let top = area.y + Math.max(0, (area.height - best.totalHeight) / 2)
    for (let r = 0; r < best.rows.length; r++) {
        let row = best.rows[r]
        let rowHeight = best.rowHeights[r]
        let rowWidth = row.reduce((sum, w) => sum + w.aspect * best.heights[w.id], 0)
                       + gap * (row.length - 1)
        let x = area.x + (area.width - rowWidth) / 2
        for (let i = 0; i < row.length; i++) {
            let w = row[i]
            let h = best.heights[w.id]
            let width = w.aspect * h
            // A card shorter than its row (a small dialog next to a browser)
            // sits on the row's baseline, so the captions stay in one line.
            result[w.id] = {
                x: Math.round(x),
                y: Math.round(top + rowHeight - h),
                width: Math.round(width),
                height: Math.round(h + captionHeight),
                frameHeight: Math.round(h)
            }
            x += width + gap
        }
        top += rowHeight + captionHeight + gap
    }
    return result
}

// One candidate: `rows` rows, as even as the count allows, the extra cards
// going to the top rows.
function planRows(ordered, rows, area, gap, captionHeight) {
    let n = ordered.length
    let base = Math.floor(n / rows)
    let extra = n % rows
    let groups = []
    let at = 0
    for (let r = 0; r < rows; r++) {
        let count = base + (r < extra ? 1 : 0)
        groups.push(ordered.slice(at, at + count).sort((a, b) => a.cx - b.cx))
        at += count
    }

    // The common height is whatever the widest row can afford, and the whole
    // block then shrinks if it does not fit vertically. Captions and gaps keep
    // their size; only the frames give way.
    let common = Infinity
    for (let r = 0; r < groups.length; r++) {
        let aspectSum = groups[r].reduce((sum, w) => sum + w.aspect, 0)
        common = Math.min(common, (area.width - gap * (groups[r].length - 1)) / aspectSum)
    }
    let fixed = captionHeight * rows + gap * (rows - 1)
    common = Math.max(1, Math.min(common, (area.height - fixed) / rows))

    // Never larger than the window itself: a small dialog on its own should
    // stay a small card.
    let heights = {}
    let rowHeights = []
    let coverage = 0
    for (let r = 0; r < groups.length; r++) {
        let tallest = 0
        for (let i = 0; i < groups[r].length; i++) {
            let w = groups[r][i]
            let h = Math.min(common, Math.max(1, w.maxHeight))
            heights[w.id] = h
            tallest = Math.max(tallest, h)
            coverage += w.aspect * h * h
        }
        rowHeights.push(tallest)
    }

    return {
        rows: groups,
        heights: heights,
        rowHeights: rowHeights,
        totalHeight: rowHeights.reduce((sum, h) => sum + h, 0) + fixed,
        coverage: coverage
    }
}

// The card to move to from `current` in a direction, by keyboard.
//
// `slots` is [{ id, cx, cy }] in one coordinate space shared by every screen,
// so the arrows cross from one monitor to the next the way the pointer does.
// Distance along the direction counts once and sideways drift twice: pressing
// right should land on the card beside this one, not a nearer one a row down.
function neighbour(slots, current, dx, dy) {
    let from = null
    for (let i = 0; i < slots.length; i++) {
        if (slots[i].id === current) from = slots[i]
    }
    if (!from) return slots.length > 0 ? slots[0].id : ""

    let bestId = ""
    let bestScore = Infinity
    for (let i = 0; i < slots.length; i++) {
        let s = slots[i]
        if (s.id === current) continue
        let along = dx !== 0 ? (s.cx - from.cx) * dx : (s.cy - from.cy) * dy
        let across = dx !== 0 ? Math.abs(s.cy - from.cy) : Math.abs(s.cx - from.cx)
        if (along <= 1) continue
        let score = along + across * 2
        if (score < bestScore) {
            bestScore = score
            bestId = s.id
        }
    }
    return bestId !== "" ? bestId : current
}
