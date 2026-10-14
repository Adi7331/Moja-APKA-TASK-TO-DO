package com.example.dzien_po_dniu

import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TaskDigestLogicTest {
    @Test
    fun latestTaskCopyControlsEligibility() {
        val dueToday = LocalDateTime.of(2026, 9, 26, 9, 0)
        val selected = tasksForDigest(
            listOf(
                TaskDigestEntry("done", "Old copy", "todo", dueToday),
                TaskDigestEntry("done", "Latest copy", "done", dueToday),
                TaskDigestEntry("moved", "Old copy", "todo", dueToday),
                TaskDigestEntry(
                    "moved",
                    "Latest copy",
                    "todo",
                    LocalDateTime.of(2026, 9, 27, 9, 0),
                ),
                TaskDigestEntry(
                    "overdue",
                    "Overdue",
                    "todo",
                    LocalDateTime.of(2026, 9, 20, 9, 0),
                ),
            ),
            LocalDateTime.of(2026, 9, 26, 12, 0),
        )

        assertEquals(listOf("overdue"), selected.map { it.id })
    }

    @Test
    fun nextOccurrenceHonorsIntervalAndReminderWindow() {
        assertEquals(
            LocalDateTime.of(2026, 9, 26, 19, 0),
            nextDigestOccurrence(
                now = LocalDateTime.of(2026, 9, 26, 14, 0, 1),
                interval = 300,
                start = 9 * 60,
                end = 21 * 60,
            ),
        )
    }

    @Test
    fun nextOccurrenceMovesToNextWindowWhenNoSlotRemains() {
        assertEquals(
            LocalDateTime.of(2026, 9, 27, 9, 0),
            nextDigestOccurrence(
                now = LocalDateTime.of(2026, 9, 26, 20, 0),
                interval = 300,
                start = 9 * 60,
                end = 21 * 60,
            ),
        )
    }

    @Test
    fun nextOccurrenceRejectsInvalidWindow() {
        assertNull(
            nextDigestOccurrence(
                now = LocalDateTime.of(2026, 9, 26, 8, 0),
                interval = 300,
                start = 9 * 60,
                end = 9 * 60,
            ),
        )
    }
}
